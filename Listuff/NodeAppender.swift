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
    var text: String
    var children: [Node] = []
    var checked: Bool? = nil
    var style: Style? = nil
    
    func allNodes() -> [Node] {
        var result = [self]
        for child in children {
            result = result + child.allNodes()
        }
        return result
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
    var list: Doc.List
    var item: AppendedItem?
    var line: Doc.Line
    init(list: Doc.List, firstNode: Node, insertLine: @escaping (String, Doc.Line?, Doc.Line) -> DocData.Line) {
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
                firstNode.children.forEach{appendNode(node: $0)}
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
        appendSublist(nodes: firstNode.children)
    }
    func appendNodeChildren(numberedList: Doc.NumberedList, numberedItem: Doc.NumberedItem, nodes: [Node]) {
        if nodes.isEmpty {
            item = .numbered(value: numberedList, item: numberedItem)
            line = numberedItem.content
        } else {
            let oldList = list
            list = numberedItem.addSublistStub(listData: nil)
            item = nil
            line = numberedItem.content
            nodes.forEach{appendNode(node: $0)}
            list = oldList
            item = .numbered(value: numberedList, item: numberedItem)
        }
    }
    func appendNode(node: Node) {
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
                    list.insertLineNumberedList(
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
        let insertedLine = list.insertLine(checked: node.checked, style: style, dir: .Right, nearItem: item?.it, callback: callback(node.text, line))
        item = .regular(value: insertedLine)
        line = insertedLine.content
        appendSublist(nodes: node.children)
    }
    func appendSublistFirst(node: Node) -> Doc.Sublist {
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
        let oldList = list
        list = sublist.list
        appendSublist(nodes: node.children)
        list = oldList
        return sublist
    }
    func appendSublist(nodes: [Node]) {
        guard let firstNode = nodes.first else {return}
        let sublist = appendSublistFirst(node: firstNode)
        let oldList = self.list
        self.list = sublist.list
        nodes.suffix(from: nodes.index(after: nodes.startIndex)).forEach{appendNode(node: $0)}
        self.list = oldList
        item = .sublist(value: sublist)
    }
}
