//
//  IdHolder.swift
//  Listuff
//
//  Created by MigMit on 15.01.2021.
//

import Foundation

struct IdHolder<Value: AnyObject>: Equatable, Hashable {
    let value: Value
    static func ==(lhs: IdHolder, rhs: IdHolder) -> Bool {
        return ObjectIdentifier(lhs.value) == ObjectIdentifier(rhs.value)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(value))
    }
}
