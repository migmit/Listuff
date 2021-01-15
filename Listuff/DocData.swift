//
//  DocData.swift
//  Listuff
//
//  Created by MigMit on 14.01.2021.
//

import Foundation
import CoreGraphics

enum DocData: DocumentTypes {
    struct LineRenderingImpl {
        let version: Int
        let rendered: NSMutableAttributedString
    }
    struct Line {
        weak var text: Partition<Structure<DocData>.Line>.Node?
        var cache: LineRenderingImpl?
        var guid: UUID?
        var backlinks: Set<IdHolder<Partition<UUID?>.Node>>
    }
    struct ListImpl {
        let version: Int
        let indent: CGFloat
    }
    typealias List = ListImpl?
    struct NumberedListImpl {
        let version: Int
        let indentStep: CGFloat
    }
    typealias NumberedList = NumberedListImpl?
}
