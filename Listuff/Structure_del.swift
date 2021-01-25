//
//  Structure_del.swift
//  Listuff
//
//  Created by MigMit on 24.01.2021.
//

import Foundation

protocol Layer {
    associatedtype Document: Layer
    associatedtype SubLayer: Layer
    associatedtype SubItem
    associatedtype SubItemCollection
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>>
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool
    func sublayer(item: SubItem) -> SubLayer?
    func splitOff(item: SubItem) -> SubItemCollection
    func join(newItems: inout SubItemCollection)
}
extension Layer {
    func fullPath(item: SubItem) -> LayerPath<Document> {appendPath(item: item, path: nil).result}
}

extension Structure.Document: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.ChapterContent
    typealias SubItem = Structure.Chapter?
    typealias SubItemCollection = Partition<Structure.Chapter, Structure.WeakProxy<Structure.Document>>
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        .done(result: LayerPath(item: item, tail: path))
    }
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool {
        return item1 === item2
    }
    func sublayer(item: SubItem) -> SubLayer? {
        if let i = item {
            return i.content
        } else {
            return beforeItems
        }
    }
    func splitOff(item: SubItem) -> SubItemCollection {
        if let chapter = item {
            let (before, _, after) = items.split(node: chapter.this!)
            items = before
            chapter.this = items.insert(value: chapter, length: 1, dir: .Left).0
            return after
        } else {
            let result = items
            let docProxy = Structure.WeakProxy<Document>()
            docProxy.value = self
            items = Partition(parent: docProxy)
            return result
        }
    }
    func linePath(line: Structure.Line) -> LayerPath<Document> {
        switch line.parent {
        case .regular(value: let regularItem):
            let item = regularItem.value!
            return item.this!.partitionParent.value!.fullPath(item: .regular(value: item))
        case .numbered(value: let numberedItem):
            let item = numberedItem.value!
            let numberedList = item.this!.partitionParent.value!
            return numberedList.this!.partitionParent.value!.fullPath(item: .numbered(list: numberedList, value: item))
        case .document(value: let doc): return doc.value!.fullPath(item: nil)
        case .chapter(value: let chapter):
            let item = chapter.value!
            return item.this!.partitionParent.value!.fullPath(item: item)
        case .section(value: let section):
            let item = section.value!
            return item.this!.partitionParent.value!.fullPath(item: item)
        case .subsection(value: let subsection):
            let item = subsection.value!
            return item.this!.partitionParent.value!.fullPath(item: item)
        }
    }
    func join(newItems: inout SubItemCollection) {
        items.union(with: &newItems)
    }
}
extension Structure.ChapterContent: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.SectionContent
    typealias SubItem = Structure.Section?
    typealias SubItemCollection = Partition<Structure.Section, Structure.WeakProxy<Structure.ChapterContent>>
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        let consPath = LayerPath<Structure.ChapterContent>(item: item, tail: path)
        switch parent {
        case .document(value: let document): return .step(continuation: {document.value!.appendPath(item: nil, path: consPath)})
        case .chapter(value: let chapter):
            let upItem = chapter.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
        }
    }
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool {
        return item1 === item2
    }
    func sublayer(item: SubItem) -> SubLayer? {
        if let i = item {
            return i.content
        } else {
            return beforeItems
        }
    }
    func splitOff(item: SubItem) -> SubItemCollection {
        if let section = item {
            let (before, _, after) = items.split(node: section.this!)
            items = before
            section.this = items.insert(value: section, length: 1, dir: .Left).0
            return after
        } else {
            let result = items
            let ccProxy = Structure.WeakProxy<Structure.ChapterContent>()
            ccProxy.value = self
            items = Partition(parent: ccProxy)
            return result
        }
    }
    func join(newItems: inout SubItemCollection) {
        items.union(with: &newItems)
    }
}
extension Structure.SectionContent: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.List
    typealias SubItem = Structure.SubSection?
    typealias SubItemCollection = Partition<Structure.SubSection, Structure.WeakProxy<Structure.SectionContent>>
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        let consPath = LayerPath<Structure.SectionContent>(item: item, tail: path)
        switch parent {
        case .chapter(value: let chapterContent): return .step(continuation: {chapterContent.value!.appendPath(item: nil, path: consPath)})
        case .section(value: let section):
            let upItem = section.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
        }
    }
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool {
        return item1 === item2
    }
    func sublayer(item: SubItem) -> SubLayer? {
        if let i = item {
            return i.content
        } else {
            return beforeItems
        }
    }
    func splitOff(item: SubItem) -> SubItemCollection {
        if let subsection = item {
            let (before, _, after) = items.split(node: subsection.this!)
            items = before
            subsection.this = items.insert(value: subsection, length: 1, dir: .Left).0
            return after
        } else {
            let result = items
            let scProxy = Structure.WeakProxy<Structure.SectionContent>()
            scProxy.value = self
            items = Partition(parent: scProxy)
            return result
        }
    }
    func join(newItems: inout SubItemCollection) {
        items.union(with: &newItems)
    }
}
extension Structure.List: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.List
    enum SubItem {
        case regular(value: Structure.RegularItem)
        case numbered(list: Structure.NumberedList, value: Structure.NumberedItem)
    }
    typealias SubItemCollection = Partition<Structure.Item, Structure.WeakProxy<Structure.List>>
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        let consPath = LayerPath<Structure.List>(item: item, tail: path)
        switch parent {
        case .regular(value: let regularItem):
            let upItem = regularItem.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: .regular(value: upItem), path: consPath)}
        case .numbered(value: let numberedItem):
            let upItem = numberedItem.value!
            let upList = upItem.this!.partitionParent.value!
            return .step {upList.this!.partitionParent.value!.appendPath(item: .numbered(list: upList, value: upItem), path: consPath)}
        case .section(value: let sectionContent): return .step(continuation: {sectionContent.value!.appendPath(item: nil, path: consPath)})
        case .subsection(value: let subsection):
            let upItem = subsection.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
        }
    }
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool {
        switch item1 {
        case .regular(value: let regularItem):
            if case .regular(value: let otherRegularItem) = item2 {
                return regularItem === otherRegularItem
            } else {
                return false
            }
        case .numbered(list: _, value: let numberedItem):
            if case .numbered(list: _, value: let otherNumberedItem) = item2 {
                return numberedItem === otherNumberedItem
            } else {
                return false
            }
        }
    }
    func sublayer(item: SubItem) -> SubLayer? {
        switch item {
        case .regular(value: let regularItem): return regularItem.sublist
        case .numbered(list: _, value: let numberedItem): return numberedItem.sublist
        }
    }
    func splitOff(item: SubItem) -> SubItemCollection {
        listData = nil
        switch(item) {
        case .regular(value: let regularItem):
            let (before, _, after) = items.split(node: regularItem.this!)
            items = before
            regularItem.this = items.insert(value: .regular(value: regularItem), length: 1, dir: .Left).0
            return after
        case .numbered(list: let numberedList, value: let numberedItem):
            numberedList.listData = nil
            var (before, _, after) = items.split(node: numberedList.this!)
            items = before
            let (numBefore, _, numAfter) = numberedList.items.split(node: numberedItem.this!)
            numberedList.items = numBefore
            numberedItem.this = numberedList.items.insert(value: numberedItem, length: 1, dir: .Left).0
            numberedList.this = items.insert(value: .numbered(value: numberedList), length: 1, dir: .Left).0
            let newNumberedList = Structure.NumberedList()
            newNumberedList.items = numAfter
            let nlProxy = Structure.WeakProxy<Structure.NumberedList>()
            nlProxy.value = newNumberedList
            newNumberedList.items.retarget(newParent: nlProxy)
            newNumberedList.this = after.insert(value: .numbered(value: newNumberedList), length: 1).0
            return after
        }
    }
    func join(newItems: inout SubItemCollection) {
        listData = nil
        if case .numbered(value: let otherNumbered) = newItems.sideValue(dir: .Left), case .numbered(value: let thisNumbered) = items.sideValue(dir: .Right) {
            thisNumbered.listData = nil
            thisNumbered.items.union(with: &otherNumbered.items)
            _ = newItems.remove(node: otherNumbered.this!)
        }
        items.union(with: &newItems)
    }
}

class LayerPath<From: Layer> {
    let item: From.SubItem
    let tail: LayerPath<From.SubLayer>?
    init(item: From.SubItem, tail: LayerPath<From.SubLayer>?) {
        self.item = item
        self.tail = tail
    }
}
