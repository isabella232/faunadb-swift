//
//  Helpers.swift
//  FaunaDB
//
//  Copyright © 2016 Fauna, Inc. All rights reserved.
//


import FaunaDB
import RxSwift

import Foundation

var faunaClient: Client = {
    return Client(secret: "kqnPAd6R_jhAAA20RPVgavy9e9kaW8bz-wWGX6DPNWI", observers: [Logger()])
}()

extension FaunaModel {
    
    func fCreate() -> Create {
        return Create(ref: Self.classRef, params: ["data": value])
    }
    
    func fUpdate() -> Update? {
        guard let refId = refId else {
            return nil
        }
        return Update(ref: refId, params: ["data": value])
    }
    
    func fDelete() -> Delete? {
        guard let refId = refId else {
            return nil
        }
        return Delete(ref: refId)
    }
    
    func fReplace() -> Replace? {
        guard let refId = refId else { return nil }
        return Replace(ref: refId, params: ["data": value])
    }
    
}

public protocol FaunaModel: ValueConvertible {
    var client: Client { get }
    static var classRef: Ref { get }
    var refId: Ref? { get }
}

extension ValueConvertible {
    var client: Client {
        return faunaClient
    }
}

extension Expr {
    
    public func rx_query() -> Observable<Value> {
        return self.client.rx_query(self)
    }
}


// Helpers to make Array and Dictionary types conforms to ValueConvertible, this may be risky so it's not included natively in the  swift FaunaDB SDK.


extension NSObject {
    
    private func value() -> Value {
        switch  self {
        case let str as NSString:
            return str as String
        case let int as NSNumber:
            if int.isDoubleNumber() {
                return int as Double
            }
            else if int.isBoolNumber() {
                return int as Bool
            }
            else {
                return int as Int
            }
        case let date as NSDate:
            return date
        case let dateComponents as NSDateComponents:
            return dateComponents
        case let nsArray as NSArray:
            var result = Arr()
            for item in nsArray {
                result.append((item as! NSObject).value())
            }
            return result
        case let nsDictionary as NSDictionary:
            var result = Obj()
            for item in nsDictionary {
                result[item.key as! String] = (item.value as! NSObject).value()
            }
            return result
        default:
            assertionFailure()
            return ""
        }
    }
}

extension NSNumber {
    
    private func isBoolNumber() -> Bool{
        return CFGetTypeID(self) == CFBooleanGetTypeID()
    }
    
    private func isDoubleNumber() -> Bool{
        return CFNumberGetType(self) == CFNumberType.DoubleType || CFNumberGetType(self) == CFNumberType.Float64Type
    }
    
}


extension Dictionary: ValueConvertible {
    
    public var value: FaunaDB.Value {
        let content: [(String, ValueConvertible)] =
            map { k, v in
                let key = k as! String
                let value = (v as? ValueConvertible) ?? (v as! NSObject).value()
                return (key, value)
        }
        
        return Obj(content)
    }
}

extension Array: ValueConvertible {
    
    public var value: Value {
        return Arr(
            filter { item in
                return item is ValueConvertible || item is NSObject
                }.map { item in
                    let valueConvertibleValue = (item as? ValueConvertible)
                    let objectValue = (item as? NSObject)?.value()
                    return objectValue ?? valueConvertibleValue!
            })
    }
}

extension Arr: ArrayLiteralConvertible {
        
    public init(arrayLiteral elements: Value...){
        self.init(elements)
    }
}

extension Obj: DictionaryLiteralConvertible {
    
    public init(dictionaryLiteral elements: (String, ValueConvertible)...){
        self.init(elements)
    }
}

