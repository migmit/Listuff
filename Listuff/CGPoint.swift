//
//  CGPoint.swift
//  Listuff
//
//  Created by MigMit on 09.01.2021.
//

import CoreGraphics

extension CGPoint {
    func shift(by: CGVector) -> CGPoint {
        return CGPoint(x: x + by.dx, y: y + by.dy)
    }
}
