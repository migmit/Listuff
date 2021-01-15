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
        case sublist(value: Doc.Sublist)
        case numbered(value: Doc.NumberedList, item: Doc.NumberedItem)
        var it: Doc.Item {
            switch self {
            case .regular(value: let value): return .regular(value: value)
            case .sublist(value: let value): return .sublist(value: value)
            case .numbered(value: let value, item: _): return .numbered(value: value)
            }
        }
    }
    let callback: (String, LineId?, [(Range<String.Index>, LineId)], Doc.Line?) -> (Doc.Line) -> DocData.Line
    let document: Doc.Document
    var chapter: Doc.Chapter?
    var chapterContent: Doc.ChapterContent
    var section: Doc.Section?
    var sectionContent: Doc.SectionContent
    var subsection: Doc.SubSection?
    var list: Doc.List?
    var item: AppendedItem?
    var line: Doc.Line?
    init(insertLine: @escaping (String, LineId?, [(Range<String.Index>, LineId)], Doc.Line?, Doc.Line) -> DocData.Line) {
        self.document = Doc.Document()
        self.chapter = nil
        self.chapterContent = document.beforeItems
        self.section = nil
        self.sectionContent = chapterContent.beforeItems
        self.subsection = nil
        self.callback = {content, linkId, links, after in {insertLine(content + "\n", linkId, links, after, $0)}}
        self.line = nil
    }
    func appendNodeChildren(numberedList: Doc.NumberedList, numberedItem: Doc.NumberedItem, nodes: [Node]) {
        line = numberedItem.content
        if !nodes.isEmpty {
            let oldList = list
            list = numberedItem.addSublistStub(listData: nil)
            item = nil
            nodes.forEach(appendNode)
            list = oldList
        }
        item = .numbered(value: numberedList, item: numberedItem)
    }
    func makeListStub() -> Doc.List {
        if let lst = list {
            return lst
        } else {
            let lst = subsection?.insertListStub(listData: nil) ?? sectionContent.insertListStub(listData: nil)
            list = lst
            return lst
        }
    }
    func appendNode(node: Node) {
        let lst = makeListStub()
        let style: Doc.LineStyle?
        switch node.style {
        case .bullet: style = .bullet
        case .dash: style = .dash
        case .number:
            let numberedList: Doc.NumberedList
            let numberedItem: Doc.NumberedItem
            if case .numbered(value: let value, item: let lastItem) = item {
                appendNodeChildren(
                    numberedList: value,
                    numberedItem: value.insertLine(checked: node.checked, dir: .Right, nearItem: lastItem, callback: callback(node.text, node.linkId, node.links, line)),
                    nodes: node.children
                )
            } else {
                (numberedList, numberedItem) =
                    lst.insertLineNumberedList(
                        checked: node.checked,
                        dir: .Right,
                        nearItem: item?.it,
                        nlistData: nil,
                        callback: callback(node.text, node.linkId, node.links, line)
                    )
                appendNodeChildren(numberedList: numberedList, numberedItem: numberedItem, nodes: node.children)
            }
            return
        case nil: style = nil
        }
        let insertedLine = lst.insertLine(checked: node.checked, style: style, dir: .Right, nearItem: item?.it, callback: callback(node.text, node.linkId, node.links, line))
        item = .regular(value: insertedLine)
        line = insertedLine.content
        appendSublist(list: lst, nodes: node.children)
    }
    func appendSublistFirst(list: Doc.List, node: Node) -> Doc.Sublist {
        let style: Doc.LineStyle?
        switch node.style {
        case .bullet: style = .bullet
        case .dash: style = .dash
        case .number:
            let (sublist, numberedList, numberedItem) =
                list.insertLineNumberedSublist(
                    checked: node.checked,
                    dir: .Right,
                    nearItem: item?.it,
                    listData: nil,
                    nlistData: nil,
                    callback: callback(node.text, node.linkId, node.links, line)
                )
            appendNodeChildren(numberedList: numberedList, numberedItem: numberedItem, nodes: node.children)
            return sublist
        case nil: style = nil
        }
        let (sublist, insertedItem) =
            list.insertLineSublist(
                checked: node.checked,
                style: style,
                dir: .Right,
                nearItem: item?.it,
                listData: nil,
                callback: callback(node.text, node.linkId, node.links, line)
            )
        item = .regular(value: insertedItem)
        line = insertedItem.content
        appendSublist(list: sublist.list, nodes: node.children)
        return sublist
    }
    func appendSublist(list: Doc.List, nodes: [Node]) {
        guard let firstNode = nodes.first else {return}
        let sublist = appendSublistFirst(list: list, node: firstNode)
        let oldList = self.list
        self.list = sublist.list
        nodes.suffix(from: nodes.index(after: nodes.startIndex)).forEach(appendNode)
        self.list = oldList
        item = .sublist(value: sublist)
    }
    func appendSection(sect: Section) {
        switch sect.level {
        case .subsection:
            let newItem = sectionContent.insertSubsection(checked: sect.checked, dir: .Right, nearItem: subsection, callback: callback(sect.text, sect.linkId, sect.links, line))
            subsection = newItem
            list = nil
            line = newItem.header
        case .section:
            let newItem = chapterContent.insertSection(checked: sect.checked, dir: .Right, nearItem: section, callback: callback(sect.text, sect.linkId, sect.links, line))
            section = newItem
            sectionContent = newItem.content
            subsection = nil
            list = nil
            line = newItem.header
        case .chapter:
            let newItem = document.insertChapter(checked: sect.checked, dir: .Right, nearItem: chapter, callback: callback(sect.text, sect.linkId, sect.links, line))
            chapter = newItem
            chapterContent = newItem.content
            section = nil
            sectionContent = chapterContent.beforeItems
            subsection = nil
            list = nil
            line = newItem.header
        }
    }
}
