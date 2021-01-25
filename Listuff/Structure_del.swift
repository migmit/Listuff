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

protocol WeakProxyProtocol: AnyObject {
    associatedtype C
    var value: C? {get set}
    init()
}
extension Structure.WeakProxy: WeakProxyProtocol {}

protocol ItemSection: AnyObject {
    associatedtype ParentProxy
    associatedtype Content
    var this: Partition<Self, ParentProxy>.Node? {get set}
    var content: Content {get}
}
extension Structure.Chapter: ItemSection {}
extension Structure.Section: ItemSection {}
extension Structure.SubSection: ItemSection {}

protocol SectionLayer: AnyObject {
    associatedtype ConcreteItem: ItemSection where ConcreteItem.ParentProxy == WProxy
    associatedtype WProxy: WeakProxyProtocol where WProxy.C == Self
    var beforeItems: ConcreteItem.Content {get set}
    var items: Partition<ConcreteItem, WProxy> {get set}
}
extension SectionLayer {
    static func itemsAreSame(item1: ConcreteItem?, item2: ConcreteItem?) -> Bool {
        return item1 === item2
    }
    func sublayer(item: ConcreteItem?) -> ConcreteItem.Content? {
        if let i = item {
            return i.content
        } else {
            return beforeItems
        }
    }
    func splitOff(item: ConcreteItem?) -> Partition<ConcreteItem, WProxy> {
        if let subitem = item {
            let (before, _, after) = items.split(node: subitem.this!)
            items = before
            subitem.this = items.insert(value: subitem, length: 1, dir: .Left).0
            return after
        } else {
            let result = items
            let proxy = WProxy()
            proxy.value = self
            items = Partition(parent: proxy)
            return result
        }
    }
    func join(newItems: inout Partition<ConcreteItem, WProxy>) {
        items.union(with: &newItems)
    }
}

extension Structure.Document: SectionLayer, Layer {
    func appendPath(item: Structure.Chapter?, path: LayerPath<Structure.ChapterContent>?) -> TailCall<LayerPath<Structure.Document>> {
        .done(result: LayerPath(item: item, tail: path))
    }
    func linePath(line: Structure.Line) -> LayerPath<Structure.Document> {
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
}
extension Structure.ChapterContent: SectionLayer, Layer {
    func appendPath(item: Structure.Section?, path: LayerPath<Structure.SectionContent>?) -> TailCall<LayerPath<Structure.Document>> {
        let consPath = LayerPath<Structure.ChapterContent>(item: item, tail: path)
        switch parent {
        case .document(value: let document): return .step(continuation: {document.value!.appendPath(item: nil, path: consPath)})
        case .chapter(value: let chapter):
            let upItem = chapter.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
        }
    }
}
extension Structure.SectionContent: SectionLayer, Layer {
    func appendPath(item: Structure.SubSection?, path: LayerPath<Structure.List>?) -> TailCall<LayerPath<Structure.Document>> {
        let consPath = LayerPath<Structure.SectionContent>(item: item, tail: path)
        switch parent {
        case .chapter(value: let chapterContent): return .step(continuation: {chapterContent.value!.appendPath(item: nil, path: consPath)})
        case .section(value: let section):
            let upItem = section.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
        }
    }
}
extension Structure.List: Layer {
    enum SubItem {
        case regular(value: Structure.RegularItem)
        case numbered(list: Structure.NumberedList, value: Structure.NumberedItem)
    }
    typealias SubItemCollection = Partition<Structure.Item, Structure.WeakProxy<Structure.List>>
    func appendPath(item: SubItem, path: LayerPath<Structure.List>?) -> TailCall<LayerPath<Structure.Document>> {
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
