//
//  ObservableProxy.swift
//  Listuff
//
//  Created by MigMit on 29.11.2020.
//

import Foundation

class ObservableProxy<V>: ObservableObject {
    @Published var value: V
    init(value: V) {
        self.value = value
    }
}
