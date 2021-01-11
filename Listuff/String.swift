//
//  String.swift
//  Listuff
//
//  Created by MigMit on 09.01.2021.
//

import UIKit

extension String {
    subscript(nsRange: NSRange) -> String {
        return (self as NSString).substring(with: nsRange)
    }
    func size(font: UIFont) -> CGSize {
        return (self as NSString).size(withAttributes: [.font: font])
    }
    func draw(at: CGPoint, withAttributes: [NSAttributedString.Key: Any]) {
        (self as NSString).draw(at: at, withAttributes: withAttributes)
    }
    func draw(in rect: CGRect, withAttributes: [NSAttributedString.Key: Any]) {
        (self as NSString).draw(in: rect, withAttributes: withAttributes)
    }
    func getLineEnd(pos: Int) -> Int {
        var result = pos
        (self as NSString).getLineStart(nil, end: nil, contentsEnd: &result, for: NSRange.empty(at: pos))
        return result
    }
}
