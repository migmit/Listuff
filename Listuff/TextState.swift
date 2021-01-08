//
//  TextState.swift
//  Listuff
//
//  Created by MigMit on 27.12.2020.
//

import Combine
import CoreGraphics
import Foundation

class TextState {
    typealias Dir = Direction
    enum DocData: DocumentTypes {
        struct Line {
            weak var text: Chunk?
            weak var line: Partition<()>.Node?
        }
        struct List {
            var version: Int
            var indent: CGFloat?
        }
        struct NumberedList {
            var version: Int
            var indentStep: CGFloat?
        }
    }
    typealias Doc = Document<DocData>
    typealias Chunk = Partition<Doc.Line>.Node
    typealias EventPublisher = AnyPublisher<Event, Never>
    enum Event {
        case Insert(node: Chunk, range: NSRange)
        case Remove(value: Doc.Line, oldRange: NSRange)
        case SetLength(value: Doc.Line, length: Int, oldRange: NSRange)
    }
    struct ListItemInfo {
        let range: NSRange
        let paragraphIndent: CGFloat
        let indexIndent: CGFloat
        let hasChekmark: Bool
        let hasBullet: Bool
    }
    var text: String
    var chunks: Partition<Doc.Line>
    var lines: Partition<()>
    var structure: Doc.List
    var indentVersion: Int
    var items: [Substring] {
        var result: [Substring] = []
        for (bounds, _) in chunks {
            if let r = Range(bounds, in: text) {
                result.append(text[r])
            }
        }
        return result
    }
    private let eventsPublisher = PassthroughSubject<Event, Never>()
    var events: EventPublisher {
        return eventsPublisher.eraseToAnyPublisher()
    }
    var numWidthCache: Partition<CGFloat>
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
    struct NodeAppendingState {
        let item: AppendedItem?
        let line: Doc.Line
    }
    init(nodes: [Node]) {
        func callback(_ content: String) -> (Doc.Line, Direction, DocData.Line?) -> DocData.Line {
            let text = content + "\n"
            self.text += text
            return {DocData.Line(
                text: self.chunks.insert(value: $0, length: text.count, dir: $1, near: $2?.text).0,
                line: self.lines.insert(value: (), length: 1, dir: $1, near: $2?.line).0
            )}
        }
        func appendNodeChildren(numberedList: Doc.NumberedList, numberedItem: Doc.NumberedItem, nodes: [Node]) -> NodeAppendingState {
            if nodes.isEmpty {
                return NodeAppendingState(item: .numbered(value: numberedList, item: numberedItem), line: numberedItem.content)
            } else {
                let sublist = numberedItem.addSublistStub(listData: DocData.List(version: indentVersion, indent: nil))
                var lastAppended = NodeAppendingState(item: nil, line: numberedItem.content)
                nodes.forEach{lastAppended = appendNode(list: sublist, after: lastAppended, node: $0)}
                return NodeAppendingState(item: .numbered(value: numberedList, item: numberedItem), line: lastAppended.line)
            }
        }
        func appendNode(list: Doc.List, after: NodeAppendingState?, node: Node) -> NodeAppendingState {
            let style: Doc.LineStyle?
            switch node.style {
            case .bullet: style = .bullet
            case .dash: style = .dash
            case .number:
                let numberedList: Doc.NumberedList
                let numberedItem: Doc.NumberedItem
                if case .numbered(value: let value, item: let item) = after?.item {
                    numberedList = value
                    numberedItem = numberedList.insertLine(checked: node.checked, dir: .Right, nearLine: after?.line, nearItem: item, callback: callback(node.text))
                } else {
                    (numberedList, numberedItem) =
                        list.insertLineNumberedList(
                            checked: node.checked,
                            dir: .Right,
                            nearLine: after?.line,
                            nearItem: after?.item?.it,
                            nlistData: DocData.NumberedList(version: indentVersion, indentStep: nil),
                            callback: callback(node.text)
                        )
                }
                return appendNodeChildren(numberedList: numberedList, numberedItem: numberedItem, nodes: node.children)
            case nil: style = nil
            }
            let insertedLine = list.insertLine(checked: node.checked, style: style, dir: .Right, nearLine: after?.line, nearItem: after?.item?.it, callback: callback(node.text))
            let lastAppended = NodeAppendingState(item: .regular(value: insertedLine), line: insertedLine.content)
            return appendSublist(list: list, after: lastAppended, nodes: node.children)
        }
        func appendSublistFirst(list: Doc.List, after: NodeAppendingState, node: Node) -> (Doc.Sublist, NodeAppendingState) {
            let style: Doc.LineStyle?
            switch node.style {
            case .bullet: style = .bullet
            case .dash: style = .dash
            case .number:
                let (sublist, numberedList, numberedItem) =
                    list.insertLineNumberedSublist(
                        checked: node.checked,
                        dir: .Right,
                        nearLine: after.line,
                        nearItem: after.item?.it,
                        listData: DocData.List(version: indentVersion, indent: nil),
                        nlistData: DocData.NumberedList(version: indentVersion, indentStep: nil),
                        callback: callback(node.text)
                    )
                return (sublist, appendNodeChildren(numberedList: numberedList, numberedItem: numberedItem, nodes: node.children))
            case nil: style = nil
            }
            let (sublist, item) =
                list.insertLineSublist(
                    checked: node.checked,
                    style: style,
                    dir: .Right,
                    nearLine: after.line,
                    nearItem: after.item?.it,
                    listData: DocData.List(version: indentVersion, indent: nil),
                    callback: callback(node.text)
                )
            let lastInserted = appendSublist(list: sublist.list, after: NodeAppendingState(item: .regular(value: item), line: item.content), nodes: node.children)
            return (sublist, lastInserted)
        }
        func appendSublist(list: Doc.List, after: NodeAppendingState, nodes: [Node]) -> NodeAppendingState {
            guard let firstNode = nodes.first else {return after}
            let (sublist, afterSublistAppended) = appendSublistFirst(list: list, after: after, node: firstNode)
            var lastInserted = afterSublistAppended
            nodes.suffix(from: nodes.index(after: nodes.startIndex)).forEach{lastInserted = appendNode(list: sublist.list, after: lastInserted, node: $0)}
            return NodeAppendingState(item: .sublist(value: sublist), line: lastInserted.line)
        }
        self.text = ""
        self.chunks = Partition()
        self.lines = Partition()
        self.indentVersion = 0
        self.structure = Document.List(listData: DocData.List(version: indentVersion, indent: 0))
        self.numWidthCache = Partition()
        var lastInserted: NodeAppendingState? = nil
        nodes.forEach {lastInserted = appendNode(list: self.structure, after: lastInserted, node: $0)}
        self.structure.debugLog()
    }
    func calcNumWidth(num: Int) -> CGFloat {
        if let (_, width) = numWidthCache.search(pos: num-1) {
            return width
        } else {
            let maxNumFoundWidth = numWidthCache.totalLength()
            var lastNode = numWidthCache.side(dir: .Right)
            var maxWidth = lastNode?.value ?? 0
            var extendCount = 0
            for n in maxNumFoundWidth..<num {
                let width = ("\(n+1)." as NSString).size(withAttributes: [.font: systemFont]).width
                if width > maxWidth {
                    maxWidth = width
                    if let ln = lastNode {
                        _ = Partition.setLength(node: ln, length: ln.length() + extendCount)
                    }
                    extendCount = 0
                    (lastNode, _) = numWidthCache.insert(value: width, length: 1, dir: .Left, near: nil)
                } else {
                    extendCount += 1
                }
            }
            if let ln = lastNode, extendCount > 0 {
                _ = Partition.setLength(node: ln, length: ln.length() + extendCount)
            }
            return maxWidth
        }
    }
    func setChunkLength(node: Chunk, length: Int) -> NSRange {
        let range = Partition.setLength(node: node, length: length)
        eventsPublisher.send(.SetLength(value: node.value, length: length, oldRange: range))
        return range
    }
    func insertChunk(value: Doc.Line, length: Int, dir: Dir = .Right, near: Chunk? = nil) -> (Chunk, Int) {
        let (node, start) = chunks.insert(value: value, length: length, dir: dir, near: near)
        eventsPublisher.send(.Insert(node: node, range: NSMakeRange(start, length)))
        return (node, start)
    }
    func removeChunk(node: Chunk) -> NSRange {
        let value = node.value
        let range = chunks.remove(node: node)
        eventsPublisher.send(.Remove(value: value, oldRange: range))
        return range
    }
    func replaceCharacters(in range: NSRange, with str: String) -> (NSRange, Int) { // changed range (could be wider than "in range"), change in length
        return (range, 0) // TOFIX
    }
    func listItemInfo(pos: Int) -> ListItemInfo? {
        return chunks.search(pos: pos).map{(rl) in
            let (range, line) = rl
            let hasBullet: Bool
            switch line.parent {
            case .numbered(value: _): hasBullet = false
            case .regular(value: let value): hasBullet = value.value?.style != nil
            }
            let (paragraphIndent, indexIndent) = calculateIndent(line: line)
            let info = ListItemInfo(
                range: range,
                paragraphIndent: paragraphIndent,
                indexIndent: indexIndent,
                hasChekmark: line.checked != nil,
                hasBullet: hasBullet
            )
            return info
        }
    }
    func calculateIndentStep(nlist: Doc.NumberedList) -> CGFloat {
        if nlist.listData.version == indentVersion, let indentStep = nlist.listData.indentStep {
            return indentStep
        }
        let indentStep = calcNumWidth(num: nlist.items.totalLength())
        nlist.listData.version = indentVersion
        nlist.listData.indentStep = indentStep
        return indentStep
    }
    func calculateIndent(list: TextState.Doc.List) -> CGFloat {
        var current = list
        var indentStack: [(TextState.Doc.List, CGFloat)] = []
        var result: CGFloat = 0
        while current.listData.version != indentVersion || current.listData.indent == nil {
            if let parent = current.parent {
                switch parent {
                case .numbered(value: let value):
                    indentStack.append((current, indentationStep + calculateIndentStep(nlist: value.value!.parent)))
                    current = value.value!.parent.parent!
                case .sublist(value: let value):
                    indentStack.append((current, indentationStep))
                    current = value.value!.parent!
                }
            } else {
                break
            }
        }
        if current.listData.version == indentVersion, let initialIndent = current.listData.indent {
            result = initialIndent
        } else {
            current.listData.version = indentVersion
            current.listData.indent = 0
        }
        for (list, indentStep) in indentStack.reversed() {
            result += indentStep
            list.listData.version = indentVersion
            list.listData.indent = result
        }
        return result
    }
    func calculateIndent(line: TextState.Doc.Line) -> (CGFloat, CGFloat) {
        switch line.parent {
        case .numbered(value: let value):
            return (calculateIndent(list: value.value!.parent.parent!), calculateIndentStep(nlist: value.value!.parent) + numListPadding)
        case .regular(value: let value):
            return (calculateIndent(list: value.value!.parent!), 0)
        }
    }
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
