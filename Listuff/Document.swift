//
//  swift
//  Listuff
//
//  Created by MigMit on 02.01.2021.
//

import Foundation

protocol Level {
    func levelUp() -> Level?
}
extension Level {
    func depth() -> Int {
        var result = 0
        var current: Level = self
        while let parent = current.levelUp() {
            current = parent
            result += 1
        }
        return result
    }
}
protocol DebugPrint {
    func debugPrint(prefix: String)
}
extension DebugPrint {
    func debugLog() {debugPrint(prefix: "")}
}
enum Document {
    typealias LineCallback = (Line, WAVLDir, WAVLTree<Line>.Node?) -> WAVLTree<Line>.Node
    class WeakProxy<C: AnyObject> {
        weak var value: C?
    }
    class List: DebugPrint {
        var items: WAVLTree<Item>
        var parent: ListParent?
        init(parent: ListParentContainer? = nil) {
            self.items = WAVLTree()
            self.parent = parent.map{ListParent(container: $0)}
        }
        func side(dir: WAVLDir) -> Item? {
            return items.side(dir: dir)?.value
        }
        func insertLine(checked: Bool?, style: LineStyle?, dir: WAVLDir, nearLine: Line?, nearItem: Item?, callback: LineCallback) -> RegularItem {
            let item = RegularItem(checked: checked, style: style, dir: dir, nearLine: nearLine, parent: self, callback: callback)
            item.this = items.insert(value: .regular(value: item), length: 1, dir: dir, near: nearItem?.impl.this).0
            return item
        }
        func insertLineSublist(checked: Bool?, style: LineStyle?, dir: WAVLDir, nearLine: Line?, nearItem: Item?, callback: LineCallback) -> (Sublist, RegularItem) {
            let sublist = Sublist(parentList: self)
            sublist.this = items.insert(value: .sublist(value: sublist), length: 1, dir: dir, near: nearItem?.impl.this).0
            let item = sublist.list.insertLine(checked: checked, style: style, dir: dir, nearLine: nearLine, nearItem: nil, callback: callback)
            return (sublist, item)
        }
        func levelUp() -> Level? {
            switch parent?.container {
            case .sublist(value: let value): return value.value
            case .numbered(value: let value): return value.value
            case nil: return nil
            }
        }
        func debugPrint(prefix: String) {
            for (_, item) in items {
                if item.impl.parent !== self {
                    print("ERROR0")
                }
                item.debugPrint(prefix: prefix)
            }
        }
    }
    enum Item: Level, DebugPrint {
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
        func levelUp() -> Level? {
            return impl.levelUp()
        }
        func debugPrint(prefix: String) {
            switch self {
            case .regular(value: let value): value.debugPrint(prefix: prefix)
            case .numbered(value: let value): value.debugPrint(prefix: prefix)
            case .sublist(value: let value): value.debugPrint(prefix: prefix)
            }
        }
    }
    class ListItem: Level {
        weak var this: WAVLTree<Item>.Node? = nil
        weak var parent: List?
        init(parent: List) {
            self.parent = parent
        }
        var item: Item? {
            return this?.value
        }
        func near(dir: WAVLDir) -> Item? {
            return this?.near(dir: dir)?.value
        }
        func levelUp() -> Level? {
            return parent?.levelUp()
        }
    }
    class RegularItem: ListItem, DebugPrint {
        var content: Line
        var style: LineStyle?
        init(content: Line, style: LineStyle?, parent: List) {
            self.content = content
            self.style = style
            super.init(parent: parent)
        }
        func debugPrint(prefix: String) {
            if case .regular(value: let rv) = content.parent, rv.value === self {
            } else {
                print("ERROR1")
            }
            content.debugPrint(prefix: prefix + (style.map{"\($0) "} ?? ""))
        }
        convenience init(checked: Bool?, style: LineStyle?, dir: WAVLDir, nearLine: Line?, parent: List, callback: LineCallback) {
            let itemProxy = WeakProxy<RegularItem>()
            let line = Line(checked: checked, dir: dir, nearLine: nearLine, parent: .regular(value: itemProxy), callback: callback)
            self.init(content: line, style: style, parent: parent)
            itemProxy.value = self
        }
    }
    class NumberedList: ListItem, DebugPrint {
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
        func debugPrint(prefix: String) {
            for (_, item) in items {
                if item.parent !== self {
                    print("ERROR2")
                }
                item.debugPrint(prefix: prefix + "| ")
            }
        }
    }
    class NumberedItem: Level, DebugPrint {
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
        func levelUp() -> Level? {
            return parent
        }
        func debugPrint(prefix: String) {
            if case .numbered(value: let ni) = content.parent, ni.value === self {
            } else {
                print("ERROR3")
            }
            content.debugPrint(prefix: prefix)
            if case .numbered(value: let ni) = sublist?.parent?.container, ni.value === self {
            } else {
                print("ERROR4")
            }
            sublist?.debugPrint(prefix: prefix + "  ")
        }
    }
    class Sublist: ListItem, DebugPrint {
        var list: List
        init(list: List, parent: List) {
            self.list = list
            super.init(parent: parent)
        }
        convenience init(parentList: List) {
            let listProxy = WeakProxy<Sublist>()
            let list = List(parent: .sublist(value: listProxy))
            self.init(list: list, parent: parentList)
            listProxy.value = self
        }
        func debugPrint(prefix: String) {
            if case .sublist(value: let sl) = list.parent?.container, sl.value === self {
            } else {
                print("ERROR5")
            }
            list.debugPrint(prefix: prefix + "  ")
        }
    }
    class Line: Level, DebugPrint {
        weak var content: WAVLTree<Line>.Node? = nil
        var checked: Checked?
        var parent: LineParent
        init(checked: Checked? = nil, parent: LineParent) {
            self.checked = checked
            self.parent = parent
        }
        convenience init(checked: Bool?, dir: WAVLDir, nearLine: Line?, parent: LineParent, callback: LineCallback) {
            self.init(checked: checked.map{Checked(value: $0)}, parent: parent)
            self.content = callback(self, dir, nearLine?.content)
        }
        func levelUp() -> Level? {
            switch parent {
            case .regular(value: let value): return value.value?.levelUp()
            case .numbered(value: let value): return value.value?.levelUp()
            }
        }
        func debugPrint(prefix: String) {
            print(prefix + (checked.map{$0.value ? "v " : "_ "} ?? "") + String(content!.end))
        }
    }
    struct Checked {
        var value: Bool
    }
    enum LineStyle {
        case dash
        case bullet
    }
    class ListParent {
        var container: ListParentContainer
        weak var this: WAVLTree<List>.Node? = nil
        init(container: ListParentContainer) {
            self.container = container
        }
    }
    enum ListParentContainer {
        case sublist(value: WeakProxy<Sublist>)
        case numbered(value: WeakProxy<NumberedItem>)
    }
    enum LineParent {
        case regular(value: WeakProxy<RegularItem>)
        case numbered(value: WeakProxy<NumberedItem>)
    }
}
