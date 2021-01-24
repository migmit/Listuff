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
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> DelayedCalculation<LayerPath<Document>>
}
extension Layer {
    func fullPath(item: SubItem) -> LayerPath<Document> {appendPath(item: item, path: nil).result}
}

extension Structure.Document: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.ChapterContent
    typealias SubItem = Structure.Chapter?
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> DelayedCalculation<LayerPath<Document>> {
        .done(result: LayerPath(head: self, item: item, tail: path))
    }
    func linePath(line: Structure.Line) -> LayerPath<Document> {
        switch line.parent {
        case .regular(value: let regularItem):
            let item = regularItem.value!
            return item.parent!.fullPath(item: .regular(value: item))
        case .numbered(value: let numberedItem):
            let item = numberedItem.value!
            let numberedList = item.parent!
            return numberedList.parent!.fullPath(item: .numbered(list: numberedList, value: item))
        case .document(value: let doc): return doc.value!.fullPath(item: nil)
        case .chapter(value: let chapter):
            let item = chapter.value!
            return item.parent!.fullPath(item: item)
        case .section(value: let section):
            let item = section.value!
            return item.parent!.fullPath(item: item)
        case .subsection(value: let subsection):
            let item = subsection.value!
            return item.parent!.fullPath(item: item)
        }
    }
}
extension Structure.ChapterContent: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.SectionContent
    typealias SubItem = Structure.Section?
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> DelayedCalculation<LayerPath<Document>> {
        let consPath = LayerPath(head: self, item: item, tail: path)
        switch parent {
        case .document(value: let document): return .step(continuation: {document.value!.appendPath(item: nil, path: consPath)})
        case .chapter(value: let chapter):
            let upItem = chapter.value!
            return .step(continuation: {upItem.parent!.appendPath(item: upItem, path: consPath)})
        }
    }
}
extension Structure.SectionContent: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.List
    typealias SubItem = Structure.SubSection?
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> DelayedCalculation<LayerPath<Document>> {
        let consPath = LayerPath(head: self, item: item, tail: path)
        switch parent {
        case .chapter(value: let chapterContent): return .step(continuation: {chapterContent.value!.appendPath(item: nil, path: consPath)})
        case .section(value: let section):
            let upItem = section.value!
            return .step(continuation: {upItem.parent!.appendPath(item: upItem, path: consPath)})
        }
    }
}
extension Structure.List: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.List
    enum SubItem {
        case regular(value: Structure.RegularItem)
        case numbered(list: Structure.NumberedList, value: Structure.NumberedItem)
    }
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> DelayedCalculation<LayerPath<Document>> {
        let consPath = LayerPath(head: self, item: item, tail: path)
        switch parent {
        case .regular(value: let regularItem):
            let upItem = regularItem.value!
            return .step(continuation: {regularItem.value!.parent!.appendPath(item: .regular(value: upItem), path: consPath)})
        case .numbered(value: let numberedItem):
            let upItem = numberedItem.value!
            let upList = upItem.parent!
            return .step(continuation: {numberedItem.value!.parent!.parent!.appendPath(item: .numbered(list: upList, value: upItem), path: consPath)})
        case .section(value: let sectionContent): return .step(continuation: {sectionContent.value!.appendPath(item: nil, path: consPath)})
        case .subsection(value: let subsection):
            let upItem = subsection.value!
            return .step(continuation: {upItem.parent!.appendPath(item: upItem, path: consPath)})
        }
    }
}

class LayerPath<From: Layer> {
    let head: From
    let item: From.SubItem
    let tail: LayerPath<From.SubLayer>?
    init(head: From, item: From.SubItem, tail: LayerPath<From.SubLayer>?) {
        self.head = head
        self.item = item
        self.tail = tail
    }
}

enum DelayedCalculation<T> {
    case done(result: T)
    case step(continuation: () -> DelayedCalculation<T>)
    var result: T {
        var current = self
        while true {
            switch current {
            case .done(result: let result): return result
            case .step(continuation: let cont): current = cont()
            }
        }
    }
}
