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
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>>
}
extension Layer {
    func fullPath(item: SubItem) -> LayerPath<Document> {appendPath(item: item, path: nil).result}
}

extension Structure.Document: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.ChapterContent
    typealias SubItem = Structure.Chapter?
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        .done(result: LayerPath(head: self, item: item, tail: path))
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
}
extension Structure.ChapterContent: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.SectionContent
    typealias SubItem = Structure.Section?
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        let consPath = LayerPath(head: self, item: item, tail: path)
        switch parent {
        case .document(value: let document): return .step(continuation: {document.value!.appendPath(item: nil, path: consPath)})
        case .chapter(value: let chapter):
            let upItem = chapter.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
        }
    }
}
extension Structure.SectionContent: Layer {
    typealias Document = Structure.Document
    typealias SubLayer = Structure.List
    typealias SubItem = Structure.SubSection?
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        let consPath = LayerPath(head: self, item: item, tail: path)
        switch parent {
        case .chapter(value: let chapterContent): return .step(continuation: {chapterContent.value!.appendPath(item: nil, path: consPath)})
        case .section(value: let section):
            let upItem = section.value!
            return .step {upItem.this!.partitionParent.value!.appendPath(item: upItem, path: consPath)}
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
    func appendPath(item: SubItem, path: LayerPath<SubLayer>?) -> TailCall<LayerPath<Document>> {
        let consPath = LayerPath(head: self, item: item, tail: path)
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