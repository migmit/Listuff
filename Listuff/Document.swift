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
            self.parent = parent.map{ListParent(container: $0)}
            let (node, _) = self.items.insert(value: .regular(value: regular), length: 1)
            regular.parent = self
            regular.this = node
        }
        init(numbered: NumberedList, parent: ListParentContainer? = nil) {
            self.items = WAVLTree()
            self.parent = parent.map{ListParent(container: $0)}
            let (node, _) = self.items.insert(value: .numbered(value: numbered), length: 1)
            numbered.parent = self
            numbered.this = node
        }
        func side(dir: WAVLDir) -> Item? {
            return items.side(dir: dir)?.value
        }
    }
    enum Item {
        case regular(value: RegularItem)
        case numbered(value: NumberedList)
        case sublist(value: Sublist)
        var impl: ListItem {
            switch(self) {
            case .regular(value: let value): return value
            case .numbered(value: let value): return value
            case .sublist(value: let value): return value
            }
        }
    }
    class ListItem {
        weak var this: WAVLTree<Item>.Node? = nil
        var parent: List
        init(parent: List) {
            self.parent = parent
        }
        var item: Item? {
            return this?.value
        }
        func near(dir: WAVLDir) -> Item? {
            return this?.near(dir: dir)?.value
        }
    }
    class RegularItem: ListItem {
        var content: Line
        var style: LineStyle?
        init(content: Line, style: LineStyle?, parent: List) {
            self.content = content
            self.style = style
            super.init(parent: parent)
        }
    }
    class NumberedList: ListItem {
        var items: WAVLTree<NumberedItem>
        init(content: Line, parent: List) {
            self.items = WAVLTree()
            super.init(parent: parent)
            let item = NumberedItem(content: content, parent: self)
            let (node, _) = self.items.insert(value: item, length: 1)
            item.this = node
        }
        func side(dir: WAVLDir) -> NumberedItem? {
            return items.side(dir: dir)?.value
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
        func near(dir: WAVLDir) -> NumberedItem? {
            return this.flatMap{$0.near(dir: dir).map{$0.value}}
        }
    }
    class Sublist: ListItem {
        var list: List
        init(list: List, parent: List) {
            self.list = list
            super.init(parent: parent)
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
