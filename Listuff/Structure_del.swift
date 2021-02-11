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
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>>
    static func itemsAreSame(item1: SubItem, item2: SubItem) -> Bool
    func sublayer(item: SubItem) -> SubLayer
    func moveSuffix(after: SubItem, from: SubItem, fromLayer: Self)
    func setAsSuffix(afterHead: SubItem, afterTail: LayerPath<SubLayer>?, fromLayer: Self) -> TailCall<()>
    func replaceWithSuffix(fromHead: SubItem, fromTail: LayerPath<SubLayer>?, fromLayer: Self) -> TailCall<()>
    func replaceContent(fromLayer: Self) -> TailCall<()>
}
extension Layer {
    func fullPath(item: SubItem) -> LayerPath<Document> {appendPath(item: item, path: nil).result}
    func cutBetweenPaths(thisPath: LayerPath<Self>?, other: Self, otherPath: LayerPath<Self>?) -> TailCall<()> {
        if let path1 = thisPath {
            if let path2 = otherPath {
                let sub1 = sublayer(item: path1.item)
                let sub2 = other.sublayer(item: path2.item)
                if other !== self || !Self.itemsAreSame(item1: path1.item, item2: path2.item) {
                    moveSuffix(after: path1.item, from: path2.item, fromLayer: other)
                }
                return .step {sub1.cutBetweenPaths(thisPath: path1.tail, other: sub2, otherPath: path2.tail)}
            } else {
                return setAsSuffix(afterHead: path1.item, afterTail: path1.tail, fromLayer: other)
            }
        } else {
            if let path2 = otherPath {
                return replaceWithSuffix(fromHead: path2.item, fromTail: path2.tail, fromLayer: other)
            } else {
                if (other === self) {
                    return .done(result: ())
                }
                return replaceContent(fromLayer: other)
            }
        }
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
    func moveSuffix(after: ConcreteItem?, from: ConcreteItem?, fromLayer: Self) {
        if let afterItem = after {
            if let fromItem = from {
                items.moveSuffix(to: afterItem.this!, from: fromItem.this!)
            } else {
                items.setAsSuffix(after: afterItem.this!, suffix: fromLayer.items)
            }
        } else {
            if let fromItem = from {
                items.replaceWithSuffix(from: fromItem.this!)
            } else {
                items.replaceContent(from: fromLayer.items)
            }
        }
    }
    fileprivate func setAsSuffix(afterHead: ConcreteItem?, afterTail: LayerPath<ConcreteItem.Content>?, fromLayer: Self) -> TailCall<()> {
        if let ah = afterHead {
            items.setAsSuffix(after: ah.this!, suffix: fromLayer.items)
        } else {
            items.replaceContent(from: fromLayer.items)
        }
        if let at = afterTail {
            return .step {self.sublayer(item: afterHead).setAsSuffix(afterHead: at.item, afterTail: at.tail, fromLayer: fromLayer.beforeItems)}
        } else {
            return self.sublayer(item: afterHead).replaceContent(fromLayer: fromLayer.beforeItems)
        }
    }
    fileprivate func replaceWithSuffix(fromHead: ConcreteItem?, fromTail: LayerPath<ConcreteItem.Content>?, fromLayer: Self) -> TailCall<()> {
        if let fh = fromHead {
            items.replaceWithSuffix(from: fh.this!)
        } else {
            items.replaceContent(from: fromLayer.items)
        }
        if let ft = fromTail {
            return .step {self.beforeItems.replaceWithSuffix(fromHead: ft.item, fromTail: ft.tail, fromLayer: self.sublayer(item: fromHead))}
        } else {
            return beforeItems.replaceContent(fromLayer: sublayer(item: fromHead))
        }
    }
    func replaceContent(fromLayer: Self) -> TailCall<()> {
        items.replaceContent(from: fromLayer.items)
        return .step {self.beforeItems.replaceContent(fromLayer: fromLayer.beforeItems)}
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
        func listItem() -> Structure.ListItem {
            switch self {
            case .regular(value: let value): return value
            case .numbered(list: let list, value: _): return list
            }
        }
        var sublist: Structure.List {
            switch self {
            case .regular(value: let value): return value.sublist
            case .numbered(list: _, value: let value): return value.sublist
            }
        }
    }
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
    fileprivate func moveSuffix(after: SubItem, from: SubItem, fromLayer: Structure.List) {
        if case .numbered(list: let afterList, value: let afterValue) = after, case .numbered(list: _, value: let fromValue) = from {
            afterList.items.moveSuffix(to: afterValue.this!, from: fromValue.this!)
        }
        items.moveSuffix(to: after.listItem().this!, from: from.listItem().this!)
    }
    fileprivate func setAsSuffix(afterHead: SubItem, afterTail: LayerPath<Structure.List>?, fromLayer: Structure.List) -> TailCall<()> {
        if case .numbered(list: let nlist, value: let nvalue) = afterHead, case .numbered(value: let fromNList) = fromLayer.items.sideValue(dir: .Left) {
            nlist.items.setAsSuffix(after: nvalue.this!, suffix: fromNList.items)
            items.moveSuffix(to: nlist.this!, from: fromNList.this!)
        } else {
            items.setAsSuffix(after: afterHead.listItem().this!, suffix: fromLayer.items)
        }
        return sublayer(item: afterHead).cutOffSuffix(afterPath: afterTail)
    }
    fileprivate func cutOffSuffix(afterPath: LayerPath<Structure.List>?) -> TailCall<()> {
        if let ap = afterPath {
            switch ap.item {
            case .numbered(list: let nlist, value: let nvalue):
                items.cutOffSuffix(after: nlist.this!)
                nlist.items.cutOffSuffix(after: nvalue.this!)
                return .step {nvalue.sublist.cutOffSuffix(afterPath: ap.tail)}
            case .regular(value: let value):
                items.cutOffSuffix(after: value.this!)
                return .step {value.sublist.cutOffSuffix(afterPath: ap.tail)}
            }
        } else {
            let listProxy = Structure.WeakProxy<Structure.List>()
            listProxy.value = self
            items = Partition(parent: listProxy)
            return .done(result: ())
        }
    }
    fileprivate func replaceWithSuffix(fromHead: SubItem, fromTail: LayerPath<Structure.List>?, fromLayer: Structure.List) -> TailCall<()> {
        var allItems = [(fromHead, fromLayer)]
        var currentPath = fromTail
        var lastLayer = fromHead.sublist
        while let path = currentPath {
            allItems.append((path.item, lastLayer))
            lastLayer = path.item.sublist
            currentPath = path.tail
        }
        items.replaceContent(from: lastLayer.items)
        var lastItem = items.sideValue(dir: .Right).map {item -> SubItem in
            switch item {
            case .regular(value: let value): return .regular(value: value)
            case .numbered(value: let nlist): return .numbered(list: nlist, value: nlist.items.sideValue(dir: .Right)!)
            }
        }
        for (item, layer) in allItems.reversed() {
            if case .numbered(list: let lastnlist, value: let lastnvalue) = lastItem, case .numbered(list: let nlist, value: let nvalue) = item {
                let lastNumberedItem = nlist.items.sideValue(dir: .Right)!
                if lastNumberedItem !== nvalue {
                    lastItem = .numbered(list: lastnlist, value: lastNumberedItem)
                }
                lastnlist.items.moveSuffix(to: lastnvalue.this!, from: nvalue.this!)
            }
            let lastLayerItem = layer.items.sideValue(dir: .Right)
            if let li = lastItem {
                items.moveSuffix(to: li.listItem().this!, from: item.listItem().this!)
            } else {
                items.replaceWithSuffix(from: item.listItem().this!)
            }
            if lastLayerItem?.impl !== item.listItem() {
                lastItem = lastLayerItem.map {item -> SubItem in
                    switch item {
                    case .regular(value: let value): return .regular(value: value)
                    case .numbered(value: let nlist): return .numbered(list: nlist, value: nlist.items.sideValue(dir: .Right)!)
                    }
                } ?? lastItem
            }
        }
        return .done(result: ())
    }
    fileprivate func replaceContent(fromLayer: Structure.List) -> TailCall<()> {
        items.replaceContent(from: fromLayer.items)
        return .done(result: ())
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
