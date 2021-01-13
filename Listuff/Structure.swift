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
    typealias LineCallback = (Line) -> DT.Line
    class WeakProxy<C: AnyObject> {
        weak var value: C?
    }
    class Document {
        var beforeItems: ChapterContent
        var items: Partition<Chapter> = Partition()
        init() {
            let documentProxy = WeakProxy<Document>()
            let beforeItems = ChapterContent(parent: .document(value: documentProxy))
            self.beforeItems = beforeItems
            documentProxy.value = self
        }
        func insertChapter(checked: Bool?, dir: Direction, nearItem: Chapter?, callback: LineCallback) -> Chapter {
            let chapter = Chapter(checked: checked, parent: self, callback: callback)
            chapter.this = items.insert(value: chapter, length: 1, dir: dir, near: nearItem?.this).0
            return chapter
        }
    }
    class Chapter {
        var header: Line
        var content: ChapterContent
        weak var parent: Document?
        weak var this: Partition<Chapter>.Node? = nil
        init(checked: Bool?, parent: Document, callback: LineCallback) {
            let chapterProxy = WeakProxy<Chapter>()
            self.header = Line(checked: checked, parent: .chapter(value: chapterProxy), callback: callback)
            self.content = ChapterContent(parent: .chapter(value: chapterProxy))
            self.parent = parent
            chapterProxy.value = self
        }
    }
    class ChapterContent {
        var beforeItems: SectionContent
        var items: Partition<Section> = Partition()
        var parent: ChapterContentParent
        init(parent: ChapterContentParent) {
            let chapterProxy = WeakProxy<ChapterContent>()
            self.beforeItems = SectionContent(parent: .chapter(value: chapterProxy))
            self.parent = parent
            chapterProxy.value = self
        }
        func insertSection(checked: Bool?, dir: Direction, nearItem: Section?, callback: LineCallback) -> Section {
            let section = Section(checked: checked, parent: self, callback: callback)
            section.this = items.insert(value: section, length: 1, dir: dir, near: nearItem?.this).0
            return section
        }
    }
    class Section {
        var header: Line
        var content: SectionContent
        weak var parent: ChapterContent?
        weak var this: Partition<Section>.Node? = nil
        init(checked: Bool?, parent: ChapterContent, callback: LineCallback) {
            let sectionProxy = WeakProxy<Section>()
            self.header = Line(checked: checked, parent: .section(value: sectionProxy), callback: callback)
            self.content = SectionContent(parent: .section(value: sectionProxy))
            self.parent = parent
            sectionProxy.value = self
        }
    }
    class SectionContent {
        var beforeItems: List? = nil
        var items: Partition<SubSection> = Partition()
        var parent: SectionContentParent
        init(parent: SectionContentParent) {
            self.parent = parent
        }
        func insertListStub(listData: DT.List) -> List {
            if let bi = beforeItems {
                return bi
            } else {
                let scProxy = WeakProxy<SectionContent>()
                scProxy.value = self
                let list = List(listData: listData, parent: .section(value: scProxy))
                beforeItems = list
                return list
            }
        }
        func insertSubsection(checked: Bool?, dir: Direction, nearItem: SubSection?, callback: LineCallback) -> SubSection {
            let subsection = SubSection(checked: checked, parent: self, callback: callback)
            subsection.this = items.insert(value: subsection, length: 1, dir: dir, near: nearItem?.this).0
            return subsection
        }
    }
    class SubSection {
        var header: Line
        var content: List? = nil
        weak var parent: SectionContent?
        weak var this: Partition<SubSection>.Node? = nil
        init(checked: Bool?, parent: SectionContent, callback: LineCallback) {
            let ssProxy = WeakProxy<SubSection>()
            self.header = Line(checked: checked, parent: .subsection(value: ssProxy), callback: callback)
            self.parent = parent
            ssProxy.value = self
        }
        func insertListStub(listData: DT.List) -> List {
            if let cnt = content {
                return cnt
            } else {
                let ssProxy = WeakProxy<SubSection>()
                let list = List(listData: listData, parent: .subsection(value: ssProxy))
                content = list
                return list
            }
        }
    }
    class List {
        var items: Partition<Item>
        var parent: ListParent
        var listData: DT.List
        init(listData: DT.List, parent: ListParent) {
            self.items = Partition()
            self.listData = listData
            self.parent = parent
        }
        func insertLine(checked: Bool?, style: LineStyle?, dir: Direction, nearItem: Item?, callback: LineCallback) -> RegularItem {
            let item = RegularItem(checked: checked, style: style, parent: self, callback: callback)
            item.this = items.insert(value: .regular(value: item), length: 1, dir: dir, near: nearItem?.impl.this).0
            return item
        }
        func insertLineSublist(checked: Bool?, style: LineStyle?, dir: Direction, nearItem: Item?, listData: DT.List, callback: LineCallback) -> (Sublist, RegularItem) {
            let sublist = Sublist(listData: listData, parent: self)
            sublist.this = items.insert(value: .sublist(value: sublist), length: 1, dir: dir, near: nearItem?.impl.this).0
            let item = sublist.list.insertLine(checked: checked, style: style, dir: dir, nearItem: nil, callback: callback)
            return (sublist, item)
        }
        func insertLineNumberedList(checked: Bool?, dir: Direction, nearItem: Item?, nlistData: DT.NumberedList, callback: LineCallback) -> (NumberedList, NumberedItem) {
            let numberedList = NumberedList(listData: nlistData, parent: self)
            numberedList.this = items.insert(value: .numbered(value: numberedList), length: 1, dir: dir, near: nearItem?.impl.this).0
            let item = numberedList.insertLine(checked: checked, dir: dir, nearItem: nil, callback: callback)
            return (numberedList, item)
        }
        func insertLineNumberedSublist(checked: Bool?, dir: Direction, nearItem: Item?, listData: DT.List, nlistData: DT.NumberedList, callback: LineCallback) -> (Sublist, NumberedList, NumberedItem) {
            let sublist = Sublist(listData: listData, parent: self)
            sublist.this = items.insert(value: .sublist(value: sublist), length: 1, dir: dir, near: nearItem?.impl.this).0
            let (numberedList, numberedItem) = sublist.list.insertLineNumberedList(checked: checked, dir: dir, nearItem: nil, nlistData: nlistData, callback: callback)
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
        init(checked: Bool?, style: LineStyle?, parent: List, callback: LineCallback) {
            let itemProxy = WeakProxy<RegularItem>()
            self.content = Line(checked: checked, parent: .regular(value: itemProxy), callback: callback)
            self.style = style
            super.init(parent: parent)
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
        func insertLine(checked: Bool?, dir: Direction, nearItem: NumberedItem?, callback: LineCallback) -> NumberedItem {
            let item = NumberedItem(checked: checked, parent: self, callback: callback)
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
        weak var parent: NumberedList?
        weak var this: Partition<NumberedItem>.Node? = nil
        init(checked: Bool?, parent: NumberedList, callback: LineCallback) {
            let itemProxy = WeakProxy<NumberedItem>()
            self.content = Line(checked: checked, parent: .numbered(value: itemProxy), callback: callback)
            self.parent = parent
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
        init(listData: DT.List, parent: List) {
            let listProxy = WeakProxy<Sublist>()
            self.list = List(listData: listData, parent: .sublist(value: listProxy))
            super.init(parent: parent)
            listProxy.value = self
        }
    }
    class Line {
        var content: DT.Line? = nil
        var checked: Checked?
        var parent: LineParent
        init(checked: Bool?, parent: LineParent, callback: LineCallback) {
            self.checked = checked.map{Checked(value: $0)}
            self.parent = parent
            self.content = callback(self)
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
        case section(value: WeakProxy<SectionContent>)
        case subsection(value: WeakProxy<SubSection>)
    }
    enum LineParent {
        case regular(value: WeakProxy<RegularItem>)
        case numbered(value: WeakProxy<NumberedItem>)
        case chapter(value: WeakProxy<Chapter>)
        case section(value: WeakProxy<Section>)
        case subsection(value: WeakProxy<SubSection>)
    }
    enum ChapterContentParent {
        case document(value: WeakProxy<Document>)
        case chapter(value: WeakProxy<Chapter>)
    }
    enum SectionContentParent {
        case chapter(value: WeakProxy<ChapterContent>)
        case section(value: WeakProxy<Section>)
    }
}
