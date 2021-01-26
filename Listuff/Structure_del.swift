//
//  Structure_del.swift
//  Listuff
//
//  Created by MigMit on 24.01.2021.
//

import Foundation

fileprivate protocol Layer: AnyObject {
    associatedtype Document: Layer
    associatedtype SubLayer: Layer
    associatedtype SubItem
    associatedtype SubItemCollection
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>>
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool
    func sublayer(item: SubItem) -> SubLayer
    func splitOff(item: SubItem) -> SubItemCollection
    func appendSubitems(newItems: inout SubItemCollection)
    func prependSubitems(newItems: inout SubItemCollection) -> SubLayer
    func empty() -> TailCall<()>
    func emptyLayer()
    func allChildren() -> (SubLayer?, SubItemCollection)
}
extension Layer {
    func fullPath(item: SubItem) -> LayerPath<Document> {appendPath(item: item, path: nil).result}
    func copyFrom(other: Self) -> TailCall<()> {
        var (defaultSublayer, itms) = other.allChildren()
        let subLayer = prependSubitems(newItems: &itms)
        if let next = defaultSublayer {
            return .step {subLayer.copyFrom(other: next)}
        } else {
            return .done(result: ())
        }
    }
    func copyAfterPath(other: Self, path: LayerPath<Self>?) -> TailCall<()> {
        guard let p = path else {return copyFrom(other: other)}
        let nextLayer = other.sublayer(item: p.item)
        var itms = other.splitOff(item: p.item)
        let subLayer = prependSubitems(newItems: &itms)
        return .step {subLayer.copyAfterPath(other: nextLayer, path: p.tail)}
    }
    func emptyAndCopyAfterPath(other: Self, path: LayerPath<Self>?) -> TailCall<()> {
        guard other === self else {
            empty().result // not doing emptyLayer in each copyAfterPath iteration, because the layer might stay the same, and we will undo our own work from the previous iteration
            return copyAfterPath(other: other, path: path)
        }
        guard let p = path else {return .done(result: ())}
        let nextLayer = sublayer(item: p.item)
        var itms = splitOff(item: p.item)
        emptyLayer()
        let subLayer = prependSubitems(newItems: &itms)
        return .step {subLayer.emptyAndCopyAfterPath(other: nextLayer, path: p.tail)}
    }
    func cutOffAfterPath(path: LayerPath<Self>?) -> TailCall<()> {
        guard let p = path else {return .done(result: ())}
        _ = splitOff(item: p.item)
        let sub = sublayer(item: p.item)
        return .step {sub.cutOffAfterPath(path: p.tail)}
    }
    func putAfterPath(path: LayerPath<Self>?, other: Self) -> TailCall<()> {
        guard let p = path else {return copyFrom(other: other)}
        var (defaultSublayer, itms) = other.allChildren()
        let subLayer = sublayer(item: p.item)
        _ = splitOff(item: p.item)
        appendSubitems(newItems: &itms)
        if let next = defaultSublayer {
            return .step {subLayer.putAfterPath(path: p.tail, other: next)}
        } else {
            return subLayer.cutOffAfterPath(path: p.tail)
        }
    }
    func cutBetweenPaths(thisPath: LayerPath<Self>?, other: Self, otherPath: LayerPath<Self>?) -> TailCall<()> {
        guard let path1 = thisPath else {
            return emptyAndCopyAfterPath(other: other, path: otherPath)
        }
        guard let path2 = otherPath else {return putAfterPath(path: path1, other: other)}
        let sub1 = sublayer(item: path1.item)
        let sub2 = other.sublayer(item: path2.item)
        if other !== self || !Self.itemsAreSame(item1: path1.item, item2: path2.item) {
            var itms = other.splitOff(item: path2.item)
            _ = splitOff(item: path1.item)
            appendSubitems(newItems: &itms)
        }
        return .step {sub1.cutBetweenPaths(thisPath: path1.tail, other: sub2, otherPath: path2.tail)}
    }
}

fileprivate protocol WeakProxyProtocol: AnyObject {
    associatedtype C
    var value: C? {get set}
    init()
}
extension Structure.WeakProxy: WeakProxyProtocol {}

fileprivate protocol ItemSection: AnyObject {
    associatedtype ParentProxy
    associatedtype Content: Layer
    var this: Partition<Self, ParentProxy>.Node? {get set}
    var content: Content {get}
}
extension Structure.Chapter: ItemSection {}
extension Structure.Section: ItemSection {}
extension Structure.SubSection: ItemSection {}

fileprivate protocol SectionLayer: AnyObject {
    associatedtype ConcreteItem: ItemSection where ConcreteItem.ParentProxy == WProxy
    associatedtype WProxy: WeakProxyProtocol where WProxy.C == Self
    var beforeItems: ConcreteItem.Content {get set}
    var items: Partition<ConcreteItem, WProxy> {get set}
}
extension SectionLayer {
    static func itemsAreSame(item1: ConcreteItem?, item2: ConcreteItem?) -> Bool {
        return item1 === item2
    }
    func sublayer(item: ConcreteItem?) -> ConcreteItem.Content {
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
    func appendSubitems(newItems: inout Partition<ConcreteItem, WProxy>) {
        items.union(with: &newItems)
    }
    func empty() -> TailCall<()> {
        let proxy = WProxy()
        proxy.value = self
        items = Partition(parent: proxy)
        return .step {self.beforeItems.empty()}
    }
    func emptyLayer() {
        let proxy = WProxy()
        proxy.value = self
        items = Partition(parent: proxy)
    }
    func prependSubitems(newItems: inout Partition<ConcreteItem, WProxy>) -> ConcreteItem.Content {
        newItems.union(with: &items)
        items = newItems
        let proxy = WProxy()
        proxy.value = self
        items.retarget(newParent: proxy)
        return beforeItems
    }
    func allChildren() -> (ConcreteItem.Content?, Partition<ConcreteItem, WProxy>) {
        return (beforeItems, items)
    }
}

extension Structure.Document: SectionLayer, Layer {
    fileprivate func appendPath(item: Structure.Chapter?, path: LayerPath<Structure.ChapterContent>?) -> TailCall<LayerPath<Structure.Document>> {
        .done(result: LayerPath(item: item, tail: path))
    }
    fileprivate func linePath(line: Structure.Line) -> LayerPath<Structure.Document>? {
        switch line.parent {
        case .regular(value: let regularItem):
            let item = regularItem.value!
            return item.this!.partitionParent.value!.fullPath(item: .regular(value: item))
        case .numbered(value: let numberedItem):
            let item = numberedItem.value!
            let numberedList = item.this!.partitionParent.value!
            return numberedList.this!.partitionParent.value!.fullPath(item: .numbered(list: numberedList, value: item))
        case .document(value: _): return nil
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
    func cutBetweenLines(after: Structure.Line, upto: Structure.Line) {
        let afterPath = linePath(line: after)
        let uptoPath = linePath(line: upto)
        cutBetweenPaths(thisPath: afterPath, other: self, otherPath: uptoPath).result
    }
}
extension Structure.ChapterContent: SectionLayer, Layer {
    fileprivate func appendPath(item: Structure.Section?, path: LayerPath<Structure.SectionContent>?) -> TailCall<LayerPath<Structure.Document>> {
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
    fileprivate func appendPath(item: Structure.SubSection?, path: LayerPath<Structure.List>?) -> TailCall<LayerPath<Structure.Document>> {
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
    fileprivate enum SubItem {
        case regular(value: Structure.RegularItem)
        case numbered(list: Structure.NumberedList, value: Structure.NumberedItem)
    }
    fileprivate typealias ListItemCollection = Partition<Structure.Item, Structure.WeakProxy<Structure.List>>
    fileprivate func appendPath(item: SubItem, path: LayerPath<Structure.List>?) -> TailCall<LayerPath<Structure.Document>> {
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
    fileprivate static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool {
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
    fileprivate func sublayer(item: SubItem) -> Structure.List {
        switch item {
        case .regular(value: let regularItem): return regularItem.sublist
        case .numbered(list: _, value: let numberedItem): return numberedItem.sublist
        }
    }
    fileprivate func splitOff(item: SubItem) -> ListItemCollection {
        switch(item) {
        case .regular(value: let regularItem):
            let (before, _, after) = items.split(node: regularItem.this!)
            items = before
            regularItem.this = items.insert(value: .regular(value: regularItem), length: 1, dir: .Left).0
            return after
        case .numbered(list: let numberedList, value: let numberedItem):
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
    fileprivate func appendSubitems(newItems: inout ListItemCollection) {
        if case .numbered(value: let otherNumbered) = newItems.sideValue(dir: .Left), case .numbered(value: let thisNumbered) = items.sideValue(dir: .Right) {
            thisNumbered.items.union(with: &otherNumbered.items)
            _ = newItems.remove(node: otherNumbered.this!)
        }
        items.union(with: &newItems)
    }
    fileprivate func empty() -> TailCall<()> {
        let listProxy = Structure.WeakProxy<Structure.List>()
        listProxy.value = self
        items = Partition(parent: listProxy)
        return .done(result: ())
    }
    fileprivate func emptyLayer() {
        let listProxy = Structure.WeakProxy<Structure.List>()
        listProxy.value = self
        items = Partition(parent: listProxy)
    }
    fileprivate func prependSubitems(newItems: inout ListItemCollection) -> Structure<DT>.List {
        let listProxy = Structure.WeakProxy<Structure.List>()
        listProxy.value = self
        newItems.retarget(newParent: listProxy)
        newItems.union(with: &items)
        items = newItems
        return self
    }
    fileprivate func allChildren() -> (Structure.List?, ListItemCollection) {
        return (nil, items)
    }
}

fileprivate class LayerPath<From: Layer> {
    let item: From.SubItem
    let tail: LayerPath<From.SubLayer>?
    init(item: From.SubItem, tail: LayerPath<From.SubLayer>?) {
        self.item = item
        self.tail = tail
    }
}
