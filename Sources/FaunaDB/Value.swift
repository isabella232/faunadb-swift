import Foundation

/**
    `Value` is the top level of the value tree hierarchy. It represents a valid
    FaunaDB entry returned by the server.

    [Reference](https://fauna.com/documentation/queries#values)

    ## Traversal API

    You can use the traversal API to traverse and convert a database entry
    to an native type.

    The traversal API uses type inference to convert the returned value to
    the desired type.

    The traversal API methods are shortcuts for field extractors.  See
    `FaunaDB.Field` for more information.

    Examples of field extractions and type conversions:

        // Attempts to convert the root value to a String
        let name: String? = try! value.get()

        // Transverses to the path "array" -> 1 -> "value" and
        // attempts to convert its result to an Int
        let count: Int? = try! value.get("array", 1, "count")

        // Using a predefined field
        let nameField = Field<String>("data", "name")
        let name = try! value.get(field: nameField)

        // Extracting an array
        let tags1 = try! value
            .at("data")
            .get(asArrayOf: Field<String>())

        let tags2: [String] = try! value.get("data")

        // Extracting a dictionary
        let nickNamesByName1 = try! value
            .at("data")
            .get(asDictionaryOf: Field<String>())

        let nickNamesByName2: [String: String] =
            try! value.get("data")

        // Extracting a struct that implements
        // FaunaDB.Decodable
        let blogPost: Post = try! value.get("data")!
*/
public protocol Value: Expr, CustomStringConvertible {}

/// Represents scalar values returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public protocol ScalarValue: Value, Equatable {
    associatedtype Wrapped
    var value: Wrapped { get }
}

extension CustomStringConvertible where Self: ScalarValue, Self.Wrapped: CustomStringConvertible {
    public var description: String {
        return value.description
    }
}

/// Represents a string returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct StringV: ScalarValue, AsJson {

    public var value: String

    public init(_ value: String) {
        self.value = value
    }

    func escape() -> JsonType {
        return .string(value)
    }
}

extension StringV: Equatable {
    public static func == (left: StringV, right: StringV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a number returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct LongV: ScalarValue, AsJson {

    public var value: Int

    public init(_ value: Int) {
        self.value = value
    }

    func escape() -> JsonType {
        return .number(value)
    }
}

extension LongV: Equatable {
    public static func == (left: LongV, right: LongV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a double returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct DoubleV: ScalarValue, AsJson {

    public var value: Double

    public init(_ value: Double) {
        self.value = value
    }

    func escape() -> JsonType {
        return .double(value)
    }
}

extension DoubleV: Equatable {
    public static func == (left: DoubleV, right: DoubleV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a boolean returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct BooleanV: ScalarValue, AsJson {

    public var value: Bool

    public init(_ value: Bool) {
        self.value = value
    }

    func escape() -> JsonType {
        return .boolean(value)
    }
}

extension BooleanV: Equatable {
    public static func == (left: BooleanV, right: BooleanV) -> Bool {
        return left.value == right.value
    }
}

/**
    Represents a timestamp returned by the server.

    [Reference](https://fauna.com/documentation/queries#values-special_types)

    - Note: You can convert a timestamp to two different types:

        - `HighPrecisionTime`: A timestamp with nanoseconds precision.
        - `Date`: A timestamp with seconds precision only.
*/
public struct TimeV: ScalarValue, AsJson {

    public var value: HighPrecisionTime

    public init(_ value: HighPrecisionTime) {
        self.value = value
    }

    /// Creates a new TimeV instance considering the `Date` provided.
    /// - Note: The timestamp created will only have seconds precision.
    /// If you need more granularity, consider using a `HighPrecisionTime` instance.
    public init(date: Date) {
        self.value = HighPrecisionTime(date: date)
    }

    init?(from string: String) {
        guard let time = HighPrecisionTime(parse: string) else { return nil }
        self.value = time
    }

    func escape() -> JsonType {
        return .object([
            "@ts": .string(value.description)
        ])
    }
}

extension TimeV: Equatable {
    public static func == (left: TimeV, right: TimeV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a date returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct DateV: ScalarValue, AsJson {

    private static let formatter = ISO8601Formatter(with: "yyyy-MM-dd")

    public var value: Date

    public init(_ value: Date) {
        self.value = value
    }

    init?(from string: String) {
        guard let time = DateV.formatter.parse(from: string) else { return nil }
        self.value = time
    }

    func escape() -> JsonType {
        return .object([
            "@date": .string(DateV.formatter.string(for: value))
        ])
    }
}

extension DateV: Equatable {
    public static func == (left: DateV, right: DateV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a Ref returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct RefV: ScalarValue, AsJson {

    public var value: String

    public init(_ value: String) {
        self.value = value
    }

    func escape() -> JsonType {
        return .object(["@ref": .string(value)])
    }
}

extension RefV: Equatable {
    public static func == (left: RefV, right: RefV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a SetRef returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct SetRefV: ScalarValue, AsJson {

    public var value: [String: Value]

    public init(_ value: [String: Value]) {
        self.value = value
    }

    func escape() -> JsonType {
        return escapeObject(with: "@set", object: value)
    }
}

extension SetRefV: Equatable {
    public static func == (left: SetRefV, right: SetRefV) -> Bool {
        return left.value == right.value
    }
}

/// Represents a null value returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct NullV: Value, AsJson {

    public let description: String = "null"

    public init() {}

    func escape() -> JsonType {
        return .null
    }
}

extension NullV: Equatable {
    public static func == (left: NullV, right: NullV) -> Bool {
        return true
    }
}

/// Represents an array returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct ArrayV: Value, AsJson {

    public let value: [Value]

    public var description: String {
        return value.description
    }

    public init(_ elements: [Value]) {
        self.value = elements
    }

    func escape() -> JsonType {
        return .array(value.map(JSON.escape))
    }
}

extension ArrayV: Equatable {
    public static func == (left: ArrayV, right: ArrayV) -> Bool {
        return left.value == right.value
    }
}

/// Represents an object returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct ObjectV: Value, AsJson {

    public let value: [String: Value]

    public var description: String {
        return value.description
    }

    public init(_ pairs: [String: Value]) {
        self.value = pairs
    }

    func escape() -> JsonType {
        return escapeObject(with: "object", object: value)
    }
}

extension ObjectV: Equatable {
    public static func == (left: ObjectV, right: ObjectV) -> Bool {
        return left.value == right.value
    }
}

private func escapeObject(with: String, object: [String: Value]) -> JsonType {
    return .object([
        with: .object(object.mapValuesT(JSON.escape))
    ])
}

/// Represents a binary blob returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct BytesV: ScalarValue, AsJson {

    public let value: Data

    public var description: String {
        return "\"\(value.base64EncodedString())\""
    }

    public init(_ value: Data) {
        self.value = value
    }

    public init(fromArray bytes: [UInt8]) {
        self.value = Data(bytes)
    }

    func escape() -> JsonType {
        return .object([
            "@bytes": .string(value.base64EncodedString())
        ])
    }
}

extension BytesV: Equatable {
    public static func == (lhs: BytesV, rhs: BytesV) -> Bool {
        return lhs.value == rhs.value
    }
}

/// Represents a query value in the FaunaDB query language.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct QueryV: Value, AsJson {

    fileprivate let lambda: JsonType

    public var description: String {
        return "QueryV(\(lambda))"
    }

    internal init(_ lambda: JsonType) {
        self.lambda = lambda
    }

    func escape() -> JsonType {
        return .object(["@query": lambda])
    }
}

extension QueryV: Equatable {
    public static func == (lhs: QueryV, rhs: QueryV) -> Bool {
        return lhs.lambda == rhs.lambda
    }
}

// swiftlint:disable cyclomatic_complexity
private func == (left: Value, right: Value) -> Bool {
    switch (left, right) {
    case (let left as ObjectV, let right as ObjectV):   return left == right
    case (let left as ArrayV, let right as ArrayV):     return left == right
    case (let left as StringV, let right as StringV):   return left == right
    case (let left as LongV, let right as LongV):       return left == right
    case (let left as DoubleV, let right as DoubleV):   return left == right
    case (let left as BooleanV, let right as BooleanV): return left == right
    case (let left as RefV, let right as RefV):         return left == right
    case (let left as SetRefV, let right as SetRefV):   return left == right
    case (let left as DateV, let right as DateV):       return left == right
    case (let left as BytesV, let right as BytesV):     return left == right
    case (let left as QueryV, let right as QueryV):     return left == right
    case is (NullV, NullV):                             return true
    default:                                            return false
    }
}

private func == (left: [String: Value], right: [String: Value]) -> Bool {
    return left.elementsEqual(right, by: { pair0, pair1 in
        return pair0.key == pair1.key && pair0.value == pair1.value
    })
}

private func == (left: [Value], right: [Value]) -> Bool {
    return left.elementsEqual(right, by: ==)
}