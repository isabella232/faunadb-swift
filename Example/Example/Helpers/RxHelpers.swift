//
//  RxHelpers.swift
//  Example
//
//  Copyright © 2016 Fauna, Inc. All rights reserved.
//

import Foundation
import RxSwift
import FaunaDB
import Result

extension FaunaDB.Client {
    
    public func rx_query(expr: Expr) -> Observable<Value> {
        return Observable.create { [weak self] subscriber in
            let task = self?.query(expr) { result in
                switch result {
                case .Failure(let error):
                    subscriber.onError(error)
                case .Success(let value):
                    subscriber.onNext(value)
                    subscriber.onCompleted()
                }
            }
            return AnonymousDisposable {
                task?.cancel()
            }
        }
    }
    
}

extension ObservableType where Self.E == Value {
    
    public func mapWithField<T: DecodableValue where T.DecodedType == T>(field: Field<T>) -> Observable<T> {
        return map { try field.get($0) }
    }
}
