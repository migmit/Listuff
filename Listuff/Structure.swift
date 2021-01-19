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
        init(listData: DT.List) {
            let documentProxy = WeakProxy<Document>()
            let beforeItems = ChapterContent(parent: .document(value: documentProxy), listData: listData)
            self.beforeItems = beforeItems
            documentProxy.value = self
        }
        func insertChapter(checked: Bool?, dir: Direction, nearItem: Chapter?, listData: DT.List, callback: LineCallback) -> Chapter {
            let chapter = Chapter(checked: checked, parent: self, listData: listData, callback: callback)
            chapter.this = items.insert(value: chapter, length: 1, dir: dir, near: nearItem?.this).0
            return chapter
        }
    }
    class Chapter {
        var header: Line
        var content: ChapterContent
        weak var parent: Document?
        weak var this: Partition<Chapter>.Node? = nil
        init(checked: Bool?, parent: Document, listData: DT.List, callback: LineCallback) {
            let chapterProxy = WeakProxy<Chapter>()
            self.header = Line(checked: checked, parent: .chapter(value: chapterProxy), callback: callback)
            self.content = ChapterContent(parent: .chapter(value: chapterProxy), listData: listData)
            self.parent = parent
            chapterProxy.value = self
        }
    }
    class ChapterContent {
        var beforeItems: SectionContent
        var items: Partition<Section> = Partition()
        var parent: ChapterContentParent
        init(parent: ChapterContentParent, listData: DT.List) {
            let chapterProxy = WeakProxy<ChapterContent>()
            self.beforeItems = SectionContent(parent: .chapter(value: chapterProxy), listData: listData)
            self.parent = parent
            chapterProxy.value = self
        }
        func insertSection(checked: Bool?, dir: Direction, nearItem: Section?, listData: DT.List, callback: LineCallback) -> Section {
            let section = Section(checked: checked, parent: self, listData: listData, callback: callback)
            section.this = items.insert(value: section, length: 1, dir: dir, near: nearItem?.this).0
            return section
        }
    }
    class Section {
        var header: Line
        var content: SectionContent
        weak var parent: ChapterContent?
        weak var this: Partition<Section>.Node? = nil
        init(checked: Bool?, parent: ChapterContent, listData: DT.List, callback: LineCallback) {
            let sectionProxy = WeakProxy<Section>()
            self.header = Line(checked: checked, parent: .section(value: sectionProxy), callback: callback)
            self.content = SectionContent(parent: .section(value: sectionProxy), listData: listData)
            self.parent = parent
            sectionProxy.value = self
        }
    }
    class SectionContent {
        var beforeItems: List
        var items: Partition<SubSection> = Partition()
        var parent: SectionContentParent
        init(parent: SectionContentParent, listData: DT.List) {
            let scProxy = WeakProxy<SectionContent>()
            self.beforeItems = List(listData: listData, parent: .section(value: scProxy))
            self.parent = parent
            scProxy.value = self
        }
        func insertSubsection(checked: Bool?, dir: Direction, nearItem: SubSection?, listData: DT.List, callback: LineCallback) -> SubSection {
            let subsection = SubSection(checked: checked, parent: self, listData: listData, callback: callback)
            subsection.this = items.insert(value: subsection, length: 1, dir: dir, near: nearItem?.this).0
            return subsection
        }
    }
    class SubSection {
        var header: Line
        var content: List
        weak var parent: SectionContent?
        weak var this: Partition<SubSection>.Node? = nil
        init(checked: Bool?, parent: SectionContent, listData: DT.List, callback: LineCallback) {
            let ssProxy = WeakProxy<SubSection>()
            self.header = Line(checked: checked, parent: .subsection(value: ssProxy), callback: callback)
            self.content = List(listData: listData, parent: .subsection(value: ssProxy))
            self.parent = parent
            ssProxy.value = self
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
        func insertLine(checked: Bool?, style: LineStyle?, dir: Direction, nearItem: Item?, listData: DT.List, callback: LineCallback) -> RegularItem {
            let item = RegularItem(checked: checked, style: style, parent: self, listData: listData, callback: callback)
            item.this = items.insert(value: .regular(value: item), length: 1, dir: dir, near: nearItem?.impl.this).0
            return item
        }
        func insertLineNumberedList(checked: Bool?, dir: Direction, nearItem: Item?, listData: DT.List, nlistData: DT.NumberedList, callback: LineCallback) -> (NumberedList, NumberedItem) {
            let numberedList = NumberedList(listData: nlistData, parent: self)
            numberedList.this = items.insert(value: .numbered(value: numberedList), length: 1, dir: dir, near: nearItem?.impl.this).0
            let item = numberedList.insertLine(checked: checked, dir: dir, nearItem: nil, listData: listData, callback: callback)
            return (numberedList, item)
        }
    }
    enum Item {
        case regular(value: RegularItem)
        case numbered(value: NumberedList)
        var impl: ListItem {
            switch self {
            case .regular(value: let value): return value
            case .numbered(value: let value): return value
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
        var sublist: List
        init(checked: Bool?, style: LineStyle?, parent: List, listData: DT.List, callback: LineCallback) {
            let itemProxy = WeakProxy<RegularItem>()
            self.content = Line(checked: checked, parent: .regular(value: itemProxy), callback: callback)
            self.style = style
            self.sublist = List(listData: listData, parent: .regular(value: itemProxy))
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
        func insertLine(checked: Bool?, dir: Direction, nearItem: NumberedItem?, listData: DT.List, callback: LineCallback) -> NumberedItem {
            let item = NumberedItem(checked: checked, parent: self, listData: listData, callback: callback)
            item.this = items.insert(value: item, length: 1, dir: dir, near: nearItem?.this).0
            return item
        }
        var count: Int {
            return items.totalLength()
        }
    }
    class NumberedItem {
        var content: Line
        var sublist: List
        weak var parent: NumberedList?
        weak var this: Partition<NumberedItem>.Node? = nil
        init(checked: Bool?, parent: NumberedList, listData: DT.List, callback: LineCallback) {
            let itemProxy = WeakProxy<NumberedItem>()
            self.content = Line(checked: checked, parent: .numbered(value: itemProxy), callback: callback)
            self.sublist = List(listData: listData, parent: .numbered(value: itemProxy))
            self.parent = parent
            itemProxy.value = self
        }
        func near(dir: Direction) -> NumberedItem? {
            return this.flatMap{$0.near(dir: dir).map{$0.value}}
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
        case regular(value: WeakProxy<RegularItem>)
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
