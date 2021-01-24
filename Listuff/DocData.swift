//
//  DocData.swift
//  Listuff
//
//  Created by MigMit on 14.01.2021.
//

import Foundation
import CoreGraphics

enum DocData: DocumentTypes {
    struct Text {
        weak var text: Partition<Structure<DocData>.Line, ()>.Node?
        var guid: UUID?
        var backlinks: Set<IdHolder<Partition<UUID?, ()>.Node>>
    }
    struct Line {
        let version: Int
        let rendered: NSMutableAttributedString
    }
    struct List {
        let version: Int
        let indent: CGFloat
    }
    struct NumberedList {
        let version: Int
        let indentStep: CGFloat
    }
}
