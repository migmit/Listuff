//
//  NodeAppender.swift
//  Listuff
//
//  Created by MigMit on 12.01.2021.
//

import Foundation

struct AppendableBase {
    let text: String
    let checked: Bool?
    let linkId: String?
    let links: [(Range<String.Index>, String)]
    init(text: String, checked: Bool? = nil, linkId: String? = nil, links: [(Range<Int>, String)] = []) {
        self.text = text
        self.checked = checked
        self.linkId = linkId
        self.links = links.map{
            let (intRange, linkId) = $0
            let start = text.index(text.startIndex, offsetBy: intRange.lowerBound)
            let end = text.index(text.startIndex, offsetBy: intRange.upperBound)
            return (start..<end, linkId)
        }
    }
}

protocol Appendable {
    var base: AppendableBase {get}
    func append(to: NodeAppender)
}

extension Appendable {
    var text: String {return base.text}
    var checked: Bool? {return base.checked}
    var linkId: String? {return base.linkId}
    var links: [(Range<String.Index>, String)] {return base.links}
}

struct Node: Appendable {
    enum Style {
        case dash
        case bullet
        case number
    }
    let base: AppendableBase
    let children: [Node]
    let style: Style?
    
    init(text: String, checked: Bool? = nil, style: Style? = nil, linkId: String? = nil, links: [(Range<Int>, String)] = [], children: [Node] = []) {
        self.base = AppendableBase(text: text, checked: checked, linkId: linkId, links: links)
        self.children = children
        self.style = style
    }

    func append(to: NodeAppender) {
        to.appendNode(node: self)
    }
}

struct Section: Appendable {
    enum Level {
        case chapter
        case section
        case subsection
    }
    let base: AppendableBase
    let level: Level
    
    init(text: String, checked: Bool? = nil, level: Level, linkId: String? = nil, links: [(Range<Int>, String)] = []) {
        self.base = AppendableBase(text: text, checked: checked, linkId: linkId, links: links)
        self.level = level
    }
    
    func append(to: NodeAppender) {
        to.appendSection(sect: self)
    }
}

class NodeAppender {
    typealias Doc = Structure<DocData>
    typealias LineId = String
    enum AppendedItem {
        case regular(value: Doc.RegularItem)
        case numbered(value: Doc.NumberedList, item: Doc.NumberedItem)
        var it: Doc.Item {
            switch self {
            case .regular(value: let value): return .regular(value: value)
            case .numbered(value: let value, item: _): return .numbered(value: value)
            }
        }
    }
    let callback: (String, LineId?, [(Range<String.Index>, LineId)]) -> (Doc.Line) -> DocData.Text
    let document: Doc.Document
    var chapterContent: Doc.ChapterContent
    var sectionContent: Doc.SectionContent
    var list: Doc.List
    var item: AppendedItem?
    init(title: String, checked: Bool? = nil, linkId: String? = nil, links: [(Range<Int>, String)], insertLine: @escaping (String, LineId?, [(Range<String.Index>, LineId)], Doc.Line) -> DocData.Text) {
        self.callback = {content, linkId, links in {insertLine(content + "\n", linkId, links, $0)}}
        let appendableTitle = AppendableBase(text: title, checked: checked, linkId: linkId, links: links)
        self.document = Doc.Document(checked: appendableTitle.checked, callback: self.callback(appendableTitle.text, appendableTitle.linkId, appendableTitle.links))
        self.chapterContent = document.beforeItems
        self.sectionContent = chapterContent.beforeItems
        self.list = document.beforeItems.beforeItems.beforeItems
    }
    func appendNodeChildren(numberedList: Doc.NumberedList, numberedItem: Doc.NumberedItem, nodes: [Node]) {
        if !nodes.isEmpty {
            let oldList = list
            list = numberedItem.sublist
            item = nil
            nodes.forEach(appendNode)
            list = oldList
        }
        item = .numbered(value: numberedList, item: numberedItem)
    }
    func appendNode(node: Node) {
        let style: Doc.LineStyle?
        switch node.style {
        case .bullet: style = .bullet
        case .dash: style = .dash
        case .number:
            if case .numbered(value: let value, item: _) = item {
                appendNodeChildren(
                    numberedList: value,
                    numberedItem: value.insertLine(checked: node.checked, dir: .Left, nearItem: nil, callback: callback(node.text, node.linkId, node.links)),
                    nodes: node.children
                )
                return
            }
            let (numberedList, numberedItem) =
                list.insertLineNumberedList(
                    checked: node.checked,
                    dir: .Left,
                    nearItem: nil,
                    callback: callback(node.text, node.linkId, node.links)
                )
            appendNodeChildren(numberedList: numberedList, numberedItem: numberedItem, nodes: node.children)
            return
        case nil: style = nil
        }
        let insertedLine = list.insertLine(checked: node.checked, style: style, dir: .Left, nearItem: nil, callback: callback(node.text, node.linkId, node.links))
        item = .regular(value: insertedLine)
        appendSublist(list: list, item: insertedLine, nodes: node.children)
    }
    func appendSublist(list: Doc.List, item: Doc.RegularItem, nodes: [Node]) {
        let oldList = self.list
        self.list = item.sublist
        nodes.forEach(appendNode)
        self.list = oldList
        self.item = .regular(value: item)
    }
    func appendSection(sect: Section) {
        switch sect.level {
        case .subsection:
            let newItem = sectionContent.insertSubsection(checked: sect.checked, dir: .Left, nearItem: nil, callback: callback(sect.text, sect.linkId, sect.links))
            list = newItem.content
        case .section:
            let newItem = chapterContent.insertSection(checked: sect.checked, dir: .Left, nearItem: nil, callback: callback(sect.text, sect.linkId, sect.links))
            sectionContent = newItem.content
            list = sectionContent.beforeItems
        case .chapter:
            let newItem = document.insertChapter(checked: sect.checked, dir: .Left, nearItem: nil, callback: callback(sect.text, sect.linkId, sect.links))
            chapterContent = newItem.content
            sectionContent = chapterContent.beforeItems
            list = sectionContent.beforeItems
        }
    }
}
