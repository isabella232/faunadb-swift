import Foundation

/**
    `Encodable` protocol is used to specify how a Swift data structure
    is converted to a valid FaunaDB value when sending data to the server.

    For example:

        struct Point { let x, y: Int }

        extension Point: Encodable {
            func encode() -> Expr {
                return Obj(
                    "x" => x,
                    "y" => y
                )
            }
        }

        //...

        client.query(
            Create(
                at: Class("points"),
                Obj("data" => Point(x: 10, y: 15))
            )
        )
*/
public protocol Encodable: Expr {
    func encode() -> Expr
}

internal protocol AsJson {
    func escape() -> JsonType
}

internal enum JsonType {
    case object([String: JsonType])
    case array([JsonType])
    case string(String)
    case number(Int)
    case double(Double)
    case boolean(Bool)
    case null
}

extension JsonType: Equatable {
    public static func == (lhs: JsonType, rhs: JsonType) -> Bool {
        switch (lhs, rhs) {
        case let (.object(a), .object(b)):   return a == b
        case let (.array(a), .array(b)):     return a == b
        case let (.string(a), .string(b)):   return a == b
        case let (.number(a), .number(b)):   return a == b
        case let (.double(a), .double(b)):   return a == b
        case let (.boolean(a), .boolean(b)): return a == b
        case (.null, .null):                 return true
        default:                             return false
        }
    }
}

internal struct JSON {

    static func data(value: Any) throws -> Data {
        return try escape(value: value).toData()
    }

    static func escape(value: Any) -> JsonType {
        if let encodable = value as? Encodable {
            return escape(value: encodable.encode())
        }

        guard let asJson = value as? AsJson else {
            fatalError(
                "Can not convert value <\(type(of: value)):\(value)> to JSON. " +
                "Custom implementations of Expr and Value protocols are supported. " +
                "You can implement the Encodable protocol instead."
            )
        }

        return asJson.escape()
    }

    static func parse(data: Data) throws -> Value {
        return try decode(data: data).toValue()
    }

    static func decode(data: Data) throws -> JsonType {
        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        return try JsonType.parse(json: json)
    }

}

private extension JsonType {

    static func parse(json: Any) throws -> JsonType {
        switch json {
        case let obj as NSDictionary: return try parse(object: obj)
        case let arr as NSArray:      return try .array(arr.map(parse))
        case let num as NSNumber:     return parse(number: num)
        case let string as String:    return .string(string)
        case is NSNull:               return .null
        default:                      throw JsonError.unsupportedType(json)
        }
    }

    private static func parse(object: NSDictionary) throws -> JsonType {
        let res: [String: JsonType] = Dictionary(pairs:
            try object.map {
                guard let key = $0.key as? String else { throw JsonError.invalidObjectKeyType($0.key) }
                return try (key, parse(json: $0.value))
            }
        )

        return .object(res)
    }

    private static func parse(number: NSNumber) -> JsonType {
        if number.isDoubleNumber() { return .double(number.doubleValue) }
        if number.isBoolNumber() { return .boolean(number.boolValue)  }
        return .number(number.intValue)
    }

}

private extension JsonType {

    func toData() throws -> Data {
        switch self {
        case .object, .array:  return try toData(json: unwrap())
        default:               return try toData(literal: unwrap())
        }
    }

    private func toData(json: Any) throws -> Data {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    }

    private func toData(literal: Any) throws -> Data {
        let asString: String

        switch literal {
        case is String: asString = "\"\(literal)\""
        case is NSNull: asString = "null"
        default:        asString = "\(literal)"
        }

        guard let data = asString.data(using: .utf8) else {
            throw JsonError.invalidLiteral(literal)
        }

        return data
    }

    private func unwrap() -> Any {
        switch self {
        case .object(let obj):   return obj.mapValuesT { $0.unwrap() }
        case .array(let arr):    return arr.map { $0.unwrap() }
        case .string(let str):   return str
        case .number(let num):   return num
        case .double(let num):   return num
        case .boolean(let bool): return bool
        case .null:              return NSNull()
        }
    }

}

private extension JsonType {

    func toValue() throws -> Value {
        switch self {
        case .object(let obj):   return try toValue(special: obj)
        case .array(let arr):    return try ArrayV(arr.map { try $0.toValue() })
        case .string(let str):   return StringV(str)
        case .number(let num):   return LongV(num)
        case .double(let num):   return DoubleV(num)
        case .boolean(let bool): return BooleanV(bool)
        case .null:              return NullV()
        }
    }

    private func toValue(special: [String: JsonType]) throws -> Value {
        guard
            let key = special.first?.key,
            let value = special.first?.value
        else {
            return ObjectV([:])
        }

        switch (key, value) {
        case ("@ref", .object(let obj)):   return try toRefV(object: obj)
        case ("@query", let obj):          return QueryV(obj)
        case ("@set", .object(let obj)):   return try convert(to: SetRefV.init, object: obj)
        case ("@obj", .object(let obj)):   return try convert(to: ObjectV.init, object: obj)
        case ("@ts", .string(let str)):    return try convert(to: TimeV.init, time: str)
        case ("@date", .string(let str)):  return try convert(to: DateV.init, time: str)
        case ("@bytes", .string(let str)): return try convert(to: BytesV.init, base64: str)
        default:                           return try convert(to: ObjectV.init, object: special)
        }
    }

    private func toRefV(object: [String: JsonType]) throws -> Value {
        guard case let .string(id)? = object["id"] else { throw JsonError.invalidRefValue }

        let clazz = try object["class"].map(forceRefV)
        let database = try object["database"].map(forceRefV)

        if clazz == nil && database == nil {
            return Native.fromName(id)
        }

        return RefV(id, class: clazz, database: database)
    }

    private func forceRefV(_ json: JsonType) throws -> RefV {
        guard let ref = try json.toValue() as? RefV else {
            throw JsonError.invalidRefValue
        }
        return ref
    }

    private func convert(to type: (Data) -> Value, base64: String) throws -> Value {
        if let data = Data(base64Encoded: base64) { return type(data) }
        throw JsonError.invalidBase64(base64)
    }

    private func convert(to type: ([String: Value]) -> Value, object: [String: JsonType]) throws -> Value {
        return try type(
            object.mapValuesT { json in
                try json.toValue()
            }
        )
    }

    private func convert(to type: (String) -> Value?, time: String) throws -> Value {
        if let parsed = type(time) { return parsed }
        throw JsonError.invalidDate(time)
    }

}

/**
    Represents all possible errors when decoding or encoding JSON.

    - unsupportedType: When the data being decoded has a type that is not supported by the driver.
    - invalidObjectKeyType: When a JSON object has a non-string key.
    - invalidLiteral: When the driver can't convert a literal type to a valid JSON type.
    - invalidDate: When the driver can't convert a date to or from JSON.
    - invalidBase64: When the driver cannot parse a base64 string.
    - invalidReference: When the driver try to parse an invalid @ref type.
*/
public enum JsonError: Error {
    case unsupportedType(Any)
    case invalidObjectKeyType(Any)
    case invalidLiteral(Any)
    case invalidDate(String)
    case invalidBase64(String)
    case invalidRefValue
}

extension JsonError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupportedType(let type):     return "Can not parse JSON type \"\(type)\""
        case .invalidObjectKeyType(let key): return "Invalid JSON object key \"\(key)\""
        case .invalidLiteral(let literal):   return "Invalid JSON literal \"\(literal)\""
        case .invalidDate(let string):       return "Invalid date \"\(string)\""
        case .invalidBase64(let string):     return "Invalid base64 sequence \"\(string)\""
        case .invalidRefValue:               return "Invalid @ref representation"
        }
    }
}
