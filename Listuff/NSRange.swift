//
//  NSRange.swift
//  Listuff
//
//  Created by MigMit on 09.01.2021.
//

import Foundation

extension NSRange {
    func shift(by: Int) -> NSRange {
        return NSMakeRange(location + by, length)
    }
    static func empty(at: Int) -> NSRange {
        return NSMakeRange(at, 0)
    }
    static func item(at: Int) -> NSRange {
        return NSMakeRange(at, 1)
    }
    var end: Int {
        return location + length
    }
    var firstItem: NSRange {
        return NSMakeRange(location, 1)
    }
}

extension NSAttributedString {
    var fullRange: NSRange {
        return NSMakeRange(0, length)
    }
}
