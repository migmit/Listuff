//
//  swift
//  Listuff
//
//  Created by MigMit on 02.01.2021.
//

import Foundation

class Document {
    class List {
        var items: WAVLTree<Item>
        var parent: ListParent?
        init(regular: RegularItem, parent: ListParentContainer? = nil) {
            self.items = WAVLTree()
            _ = self.items.insert(value: .regular(value: regular), length: 1)
            self.parent = parent.map{ListParent(container: $0)}
        }
        init(numbered: NumberedList, parent: ListParentContainer? = nil) {
            self.items = WAVLTree()
            _ = self.items.insert(value: .numbered(value: numbered), length: 1)
        }
    }
    enum Item {
        case regular(value: RegularItem)
        case numbered(value: NumberedList)
        case sublist(value: Sublist)
        var parent: List {
            get {
                switch(self) {
                case .regular(value: let value): return value.parent
                case .numbered(value: let value): return value.parent
                case .sublist(value: let value): return value.parent
                }
            }
            set(parent) {
                switch(self) {
                case .regular(value: let value): value.parent = parent
                case .numbered(value: let value): value.parent = parent
                case .sublist(value: let value): value.parent = parent
                }
            }
        }
        var this: WAVLTree<Item>.Node? {
            get {
                switch(self) {
                case .regular(value: let value): return value.this
                case .numbered(value: let value): return value.this
                case .sublist(value: let value): return value.this
                }
            }
            set(this) {
                switch(self) {
                case .regular(value: let value): value.this = this
                case .numbered(value: let value): value.this = this
                case .sublist(value: let value): value.this = this
                }
            }
        }
    }
    class RegularItem {
        var content: Line
        var style: LineStyle
        var parent: List
        weak var this: WAVLTree<Item>.Node? = nil
        init(content: Line, style: LineStyle, parent: List) {
            self.content = content
            self.style = style
            self.parent = parent
        }
    }
    class NumberedList {
        var items: WAVLTree<NumberedItem>
        var parent: List
        weak var this: WAVLTree<Item>.Node? = nil
        init(parent: List) {
            self.items = WAVLTree()
            self.parent = parent
        }
        init(content: Line, parent: List) {
            self.items = WAVLTree()
            self.parent = parent
            let item = NumberedItem(content: content, parent: self)
            let (node, _) = self.items.insert(value: item, length: 1)
            item.this = node
        }
    }
    class NumberedItem {
        var content: Line
        var sublist: List? = nil
        var parent: NumberedList
        weak var this: WAVLTree<NumberedItem>.Node? = nil
        init(content: Line, parent: NumberedList) {
            self.content = content
            self.parent = parent
        }
    }
    class Sublist {
        var list: List
        var parent: List
        weak var this: WAVLTree<Item>.Node? = nil
        init(list: List, parent: List) {
            self.list = list
            self.parent = parent
        }
    }
    class Line {
        weak var content: WAVLTree<Line>.Node? = nil
        var checked: Checked?
        var parent: LineParent
        init(checked: Checked? = nil, parent: LineParent) {
            self.checked = checked
            self.parent = parent
        }
    }
    struct Checked {
        var value: Bool
    }
    enum LineStyle {
        case dash
        case bullet
    }
    struct ListParent {
        var container: ListParentContainer
        weak var this: WAVLTree<List>.Node? = nil
    }
    enum ListParentContainer {
        case sublist(value: Sublist)
        case numbered(value: NumberedItem)
    }
    enum LineParent {
        case regular(value: RegularItem)
        case numbered(value: NumberedItem)
    }
}
