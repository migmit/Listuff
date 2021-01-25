//
//  TailCall.swift
//  Listuff
//
//  Created by MigMit on 25.01.2021.
//

import Foundation

enum TailCall<T> {
    case done(result: T)
    case step(continuation: () -> TailCall<T>)
    var result: T {
        var current = self
        while true {
            switch current {
            case .done(result: let result): return result
            case .step(continuation: let cont): current = cont()
            }
        }
    }
}
