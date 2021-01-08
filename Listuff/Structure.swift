//
//  swift
//  Listuff
//
//  Created by MigMit on 02.01.2021.
//

import Foundation

protocol DocumentTypes {
    associatedtype Line
    associatedtype List
    associatedtype NumberedList
}

enum Structure<DT: DocumentTypes> {
    typealias LineCallback = (Line, Direction, DT.Line?) -> DT.Line
    class WeakProxy<C: AnyObject> {
        weak var value: C?
    }
    class List {
        var items: Partition<Item>
        var parent: ListParent?
        var listData: DT.List
        init(listData: DT.List, parent: ListParent? = nil) {
            self.items = Partition()
            self.listData = listData
            self.parent = parent
        }
        func side(dir: Direction) -> Item? {
            return items.side(dir: dir)?.value
        }
        func insertLine(checked: Bool?, style: LineStyle?, dir: Direction, nearLine: Line?, nearItem: Item?, callback: LineCallback) -> RegularItem {
            let item = RegularItem(checked: checked, style: style, dir: dir, nearLine: nearLine, parent: self, callback: callback)
            item.this = items.insert(value: .regular(value: item), length: 1, dir: dir, near: nearItem?.impl.this).0
            return item
        }
        func insertLineSublist(checked: Bool?, style: LineStyle?, dir: Direction, nearLine: Line?, nearItem: Item?, listData: DT.List, callback: LineCallback) -> (Sublist, RegularItem) {
            let sublist = Sublist(listData: listData, parentList: self)
            sublist.this = items.insert(value: .sublist(value: sublist), length: 1, dir: dir, near: nearItem?.impl.this).0
            let item = sublist.list.insertLine(checked: checked, style: style, dir: dir, nearLine: nearLine, nearItem: nil, callback: callback)
            return (sublist, item)
        }
        func insertLineNumberedList(checked: Bool?, dir: Direction, nearLine: Line?, nearItem: Item?, nlistData: DT.NumberedList, callback: LineCallback) -> (NumberedList, NumberedItem) {
            let numberedList = NumberedList(listData: nlistData, parent: self)
            numberedList.this = items.insert(value: .numbered(value: numberedList), length: 1, dir: dir, near: nearItem?.impl.this).0
            let item = numberedList.insertLine(checked: checked, dir: dir, nearLine: nearLine, nearItem: nil, callback: callback)
            return (numberedList, item)
        }
        func insertLineNumberedSublist(checked: Bool?, dir: Direction, nearLine: Line?, nearItem: Item?, listData: DT.List, nlistData: DT.NumberedList, callback: LineCallback) -> (Sublist, NumberedList, NumberedItem) {
            let sublist = Sublist(listData: listData, parentList: self)
            sublist.this = items.insert(value: .sublist(value: sublist), length: 1, dir: dir, near: nearItem?.impl.this).0
            let (numberedList, numberedItem) = sublist.list.insertLineNumberedList(checked: checked, dir: dir, nearLine: nearLine, nearItem: nil, nlistData: nlistData, callback: callback)
            return (sublist, numberedList, numberedItem)
        }
    }
    enum Item {
        case regular(value: RegularItem)
        case numbered(value: NumberedList)
        case sublist(value: Sublist)
        var impl: ListItem {
            switch self {
            case .regular(value: let value): return value
            case .numbered(value: let value): return value
            case .sublist(value: let value): return value
            }
        }
    }
    class ListItem {
        weak var this: Partition<Item>.Node? = nil
        weak var parent: List?
        init(parent: List) {
            self.parent = parent
        }
        var item: Item? {
            return this?.value
        }
        func near(dir: Direction) -> Item? {
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
        convenience init(checked: Bool?, style: LineStyle?, dir: Direction, nearLine: Line?, parent: List, callback: LineCallback) {
            let itemProxy = WeakProxy<RegularItem>()
            let line = Line(checked: checked, dir: dir, nearLine: nearLine, parent: .regular(value: itemProxy), callback: callback)
            self.init(content: line, style: style, parent: parent)
            itemProxy.value = self
        }
    }
    class NumberedList: ListItem {
        var items: Partition<NumberedItem>
        var listData: DT.NumberedList
        init(listData: DT.NumberedList, parent: List) {
            self.items = Partition()
            self.listData = listData
            super.init(parent: parent)
        }
        func side(dir: Direction) -> NumberedItem? {
            return items.side(dir: dir)?.value
        }
        func insertLine(checked: Bool?, dir: Direction, nearLine: Line?, nearItem: NumberedItem?, callback: LineCallback) -> NumberedItem {
            let item = NumberedItem(checked: checked, dir: dir, nearLine: nearLine, parent: self, callback: callback)
            item.this = items.insert(value: item, length: 1, dir: dir, near: nearItem?.this).0
            return item
        }
        var count: Int {
            return items.totalLength()
        }
    }
    class NumberedItem {
        var content: Line
        var sublist: List? = nil
        var parent: NumberedList
        weak var this: Partition<NumberedItem>.Node? = nil
        init(content: Line, parent: NumberedList) {
            self.content = content
            self.parent = parent
        }
        convenience init(checked: Bool?, dir: Direction, nearLine: Line?, parent: NumberedList, callback: LineCallback) {
            let itemProxy = WeakProxy<NumberedItem>()
            let line = Line(checked: checked, dir: dir, nearLine: nearLine, parent: .numbered(value: itemProxy), callback: callback)
            self.init(content: line, parent: parent)
            itemProxy.value = self
        }
        func addSublistStub(listData: DT.List) -> List {
            if let sl = sublist {
                return sl
            } else {
                let itemProxy = WeakProxy<NumberedItem>()
                itemProxy.value = self
                let sl = List(listData: listData, parent: .numbered(value: itemProxy))
                sublist = sl
                return sl
            }
        }
        func near(dir: Direction) -> NumberedItem? {
            return this.flatMap{$0.near(dir: dir).map{$0.value}}
        }
    }
    class Sublist: ListItem {
        var list: List
        init(list: List, parent: List) {
            self.list = list
            super.init(parent: parent)
        }
        convenience init(listData: DT.List, parentList: List) {
            let listProxy = WeakProxy<Sublist>()
            let list = List(listData: listData, parent: .sublist(value: listProxy))
            self.init(list: list, parent: parentList)
            listProxy.value = self
        }
        func debugPrint(prefix: String) {
            if case .sublist(value: let sl) = list.parent, sl.value === self {
            } else {
                print("ERROR5")
            }
        }
    }
    class Line {
        var content: DT.Line? = nil
        var checked: Checked?
        var parent: LineParent
        init(checked: Checked? = nil, parent: LineParent) {
            self.checked = checked
            self.parent = parent
        }
        convenience init(checked: Bool?, dir: Direction, nearLine: Line?, parent: LineParent, callback: LineCallback) {
            self.init(checked: checked.map{Checked(value: $0)}, parent: parent)
            self.content = callback(self, dir, nearLine?.content)
        }
    }
    struct Checked {
        var value: Bool
    }
    enum LineStyle {
        case dash
        case bullet
    }
    enum ListParent {
        case sublist(value: WeakProxy<Sublist>)
        case numbered(value: WeakProxy<NumberedItem>)
    }
    enum LineParent {
        case regular(value: WeakProxy<RegularItem>)
        case numbered(value: WeakProxy<NumberedItem>)
    }
}
