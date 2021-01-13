//
//  NodeAppender.swift
//  Listuff
//
//  Created by MigMit on 12.01.2021.
//

import Foundation
import CoreGraphics

enum DocData: DocumentTypes {
    struct LineRenderingImpl {
        let version: Int
        let rendered: NSMutableAttributedString
    }
    struct Line {
        weak var text: Partition<Structure<DocData>.Line>.Node?
        var cache: LineRenderingImpl?
    }
    struct ListImpl {
        let version: Int
        let indent: CGFloat
    }
    typealias List = ListImpl?
    struct NumberedListImpl {
        let version: Int
        let indentStep: CGFloat
    }
    typealias NumberedList = NumberedListImpl?
}

struct Node {
    enum Style {
        case dash
        case bullet
        case number
    }
    let text: String
    let children: [Node]
    let checked: Bool?
    let style: Style?
    
    init(text: String, children: [Node] = [], checked: Bool? = nil, style: Style? = nil) {
        self.text = text
        self.children = children
        self.checked = checked
        self.style = style
    }
    
    func allNodes() -> [Node] {
        var result = [self]
        for child in children {
            result = result + child.allNodes()
        }
        return result
    }
}

struct Section {
    enum Level {
        case chapter
        case section
        case subsection
    }
    let text: String
    let checked: Bool?
    let level: Level
    
    init(text: String, checked: Bool? = nil, level: Level) {
        self.text = text
        self.checked = checked
        self.level = level
    }
}

class NodeAppender {
    typealias Doc = Structure<DocData>
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
    let callback: (String, Doc.Line?) -> (Doc.Line) -> DocData.Line
    let document: Doc.Document
    var chapter: Doc.Chapter?
    var chapterContent: Doc.ChapterContent
    var section: Doc.Section?
    var sectionContent: Doc.SectionContent
    var subsection: Doc.SubSection?
    var list: Doc.List?
    var item: AppendedItem?
    var line: Doc.Line
    init(firstNode: Node, insertLine: @escaping (String, Doc.Line?, Doc.Line) -> DocData.Line) {
        self.document = Doc.Document()
        self.chapter = nil
        self.chapterContent = document.beforeItems
        self.section = nil
        self.sectionContent = chapterContent.beforeItems
        self.subsection = nil
        let list = sectionContent.insertListStub(listData: nil)
        let callback = {content, after in {insertLine(content + "\n", after, $0)}}
        self.callback = callback
        let style: Doc.LineStyle?
        switch firstNode.style {
        case .bullet: style = .bullet
        case .dash: style = .dash
        case .number:
            let numberedList: Doc.NumberedList
            let numberedItem: Doc.NumberedItem
            (numberedList, numberedItem) =
                list.insertLineNumberedList(
                    checked: firstNode.checked,
                    dir: .Right,
                    nearItem: nil,
                    nlistData: nil,
                    callback: callback(firstNode.text, nil)
                )
            self.line = numberedItem.content
            if !firstNode.children.isEmpty {
                self.item = nil
                self.list = numberedItem.addSublistStub(listData: nil)
                firstNode.children.forEach(appendNode)
            }
            self.list = list
            item = .numbered(value: numberedList, item: numberedItem)
            return
        case nil: style = nil
        }
        let insertedLine = list.insertLine(checked: firstNode.checked, style: style, dir: .Right, nearItem: nil, callback: callback(firstNode.text, nil))
        self.item = .regular(value: insertedLine)
        self.line = insertedLine.content
        self.list = list
        appendSublist(list: list, nodes: firstNode.children)
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
                    numberedItem: value.insertLine(checked: node.checked, dir: .Right, nearItem: lastItem, callback: callback(node.text, line)),
                    nodes: node.children
                )
            } else {
                (numberedList, numberedItem) =
                    lst.insertLineNumberedList(
                        checked: node.checked,
                        dir: .Right,
                        nearItem: item?.it,
                        nlistData: nil,
                        callback: callback(node.text, line)
                    )
                appendNodeChildren(numberedList: numberedList, numberedItem: numberedItem, nodes: node.children)
            }
            return
        case nil: style = nil
        }
        let insertedLine = lst.insertLine(checked: node.checked, style: style, dir: .Right, nearItem: item?.it, callback: callback(node.text, line))
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
                    callback: callback(node.text, line)
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
                callback: callback(node.text, line)
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
            let newItem = sectionContent.insertSubsection(checked: sect.checked, dir: .Right, nearItem: subsection, callback: callback(sect.text, line))
            subsection = newItem
            list = nil
        case .section:
            let newItem = chapterContent.insertSection(checked: sect.checked, dir: .Right, nearItem: section, callback: callback(sect.text, line))
            section = newItem
            sectionContent = newItem.content
            subsection = nil
            list = nil
        case .chapter:
            let newItem = document.insertChapter(checked: sect.checked, dir: .Right, nearItem: chapter, callback: callback(sect.text, line))
            chapter = newItem
            chapterContent = newItem.content
            section = nil
            sectionContent = chapterContent.beforeItems
            subsection = nil
            list = nil
        }
    }
}