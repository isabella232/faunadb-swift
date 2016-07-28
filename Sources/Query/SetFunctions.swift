//
//  SetFunctions.swift
//  FaunaDB
//
//  Copyright © 2016 Fauna, Inc. All rights reserved.
//

import Foundation



public struct Match: Expr {

    public let value: Value

    /**
     `Match` returns the set of instances that match the terms, based on the configuration of the specified index. terms can be either a single value, or an array.

     [Reference](https://faunadb.com/documentation/queries#sets)

     - parameter index: index to use to perform the match.
     - parameter terms: terms can be either a single value, or multiple values. The number of terms provided must match the number of term fields indexed by indexRef. If indexRef is configured with no terms, then terms may be omitted.

     - returns: a Match expression.
     */
    public init(index: Expr, terms: Expr...){
        value = {
            var obj = Obj(fnCall:["match": index])
            obj["terms"] = terms.count > 0 ? varargs(terms) : nil
            return obj
        }()
    }
}

public struct Union: Expr {

    public let value: Value


    /**
     `Union` represents the set of resources that are present in at least one of the specified sets.

     [Reference](https://faunadb.com/documentation/queries#sets)

     - parameter sets: sets of resources to perform Union expression.

     - returns: An Union Expression.
     */
    public init(sets: Expr...){
        value = Obj(fnCall:["union": varargs(sets)])
    }
}

public struct Intersection: Expr {

    public let value: Value

    /**
     `Intersection` represents the set of resources that are present in all of the specified sets.

     [Reference](https://faunadb.com/documentation/queries#sets)

     - parameter sets: sets of resources to perform Intersection expression.

     - returns: An Intersection expression.
     */
    public init(sets: Expr...){
        value = Obj(fnCall:["intersection": varargs(sets)])
    }
}

public struct Difference: Expr {

    public let value: Value

    /**
     `Difference` represents the set of resources present in the source set and not in any of the other specified sets.

     [Reference](https://faunadb.com/documentation/queries#sets)

     - parameter sets: sets of resources to perform Difference expression.

     - returns: An Intersection expression.
     */
    public init(sets: Expr...){
        value = Obj(fnCall:["difference": varargs(sets)])
    }
}

public struct Distinct: Expr {

    public let value: Value

    /**
     Distinct function returns the set after removing duplicates.

     [Reference](https://faunadb.com/documentation/queries#sets)

     - parameter set: determines the set where distinct function should be performed.

     - returns: A Distinct expression.
     */
    public init(set: Expr){
        value = Obj(fnCall:["distinct": set])
    }
}

public struct Join: Expr {

    public let value: Value

    /**
     `Join` derives a set of resources from target by applying each instance in `sourceSet` to `with` target. Target can be either an index reference or a lambda function.
     The index form is useful when the instances in the `sourceSet` match the terms in an index. The join returns instances from index (specified by with) that match the terms from `sourceSet`.

     [Reference](https://faunadb.com/documentation/queries#sets)

     - parameter sourceSet: set to perform the join.
     - parameter with:      `with` target can be either an index reference or a lambda function.

     - returns: A `Join` expression.
     */
    public init(sourceSet: Expr, with: Expr){
        value = Obj(fnCall:["join": sourceSet, "with": with])
    }
}
