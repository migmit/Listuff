//
//  TextState.swift
//  Listuff
//
//  Created by MigMit on 27.12.2020.
//

import Foundation
import Combine

class TextState {
    typealias Dir = WAVLDir
    typealias Chunk = WAVLTree<Document.Line>.Node
    typealias EventPublisher = AnyPublisher<Event, Never>
    enum Event {
        case Insert(node: Chunk, range: NSRange)
        case Remove(value: Document.Line, oldRange: NSRange)
        case SetLength(value: Document.Line, length: Int, oldRange: NSRange)
    }
    struct ListItemInfo {
        let range: NSRange
        let depth: Int
    }
    var string: String
    var content: WAVLTree<Document.Line>
    var document: Document.List
    var items: [Substring] {
        var result: [Substring] = []
        for (bounds, _) in content {
            if let r = Range(bounds, in: string) {
                result.append(string[r])
            }
        }
        return result
    }
    private let eventsPublisher = PassthroughSubject<Event, Never>()
    var events: EventPublisher {
        return eventsPublisher.eraseToAnyPublisher()
    }
    struct NodeAppendingState {
        let item: Document.Item
        let line: Document.Line
    }
    init(nodes: [Node]) {
        func callback(_ content: String) -> (Document.Line, WAVLDir, WAVLTree<Document.Line>.Node?) -> WAVLTree<Document.Line>.Node {
            let text = content + "\n"
            self.string += text
            return {self.content.insert(value: $0, length: text.count, dir: $1, near: $2).0}
        }
        func appendNode(list: Document.List, after: NodeAppendingState?, node: Node) -> NodeAppendingState {
            let style: Document.LineStyle?
            switch node.style {
            case .bullet: style = .bullet
            case .dash: style = .dash
            default: style = nil
            }
            let insertedLine = list.insertLine(checked: node.checked, style: style, dir: .Right, nearLine: after?.line, nearItem: after?.item, callback: callback(node.text))
            let lastAppended = NodeAppendingState(item: Document.Item.regular(value: insertedLine), line: insertedLine.content)
            return appendSublist(list: list, after: lastAppended, nodes: node.children)
        }
        func appendSublist(list: Document.List, after: NodeAppendingState, nodes: [Node]) -> NodeAppendingState {
            guard let firstNode = nodes.first else {return after}
            let style: Document.LineStyle?
            switch firstNode.style {
            case .bullet: style = .bullet
            case .dash: style = .dash
            default: style = nil
            }
            let (sublist, item) = list.insertLineSublist(checked: firstNode.checked, style: style, dir: .Right, nearLine: after.line, nearItem: after.item, callback: callback(firstNode.text))
            var lastInserted = NodeAppendingState(item: Document.Item.regular(value: item), line: item.content)
            lastInserted = appendSublist(list: sublist.list, after: lastInserted, nodes: firstNode.children)
            for node in nodes.suffix(from: nodes.index(after: nodes.startIndex)) {
                lastInserted = appendNode(list: sublist.list, after: lastInserted, node: node)
            }
            return NodeAppendingState(item: Document.Item.sublist(value: sublist), line: lastInserted.line)
        }
        self.string = ""
        self.content = WAVLTree()
        self.document = Document.List()
        var lastInserted: NodeAppendingState? = nil
        for node in nodes {
            lastInserted = appendNode(list: self.document, after: lastInserted, node: node)
        }
        self.document.debugLog()
    }
    func setChunkLength(node: Chunk, length: Int) -> NSRange {
        let range = WAVLTree.setLength(node: node, length: length)
        eventsPublisher.send(.SetLength(value: node.value, length: length, oldRange: range))
        return range
    }
    func insertChunk(value: Document.Line, length: Int, dir: Dir = .Right, near: Chunk? = nil) -> (Chunk, Int) {
        let (node, start) = content.insert(value: value, length: length, dir: dir, near: near)
        eventsPublisher.send(.Insert(node: node, range: NSMakeRange(start, length)))
        return (node, start)
    }
    func removeChunk(node: Chunk) -> NSRange {
        let value = node.value
        let range = content.remove(node: node)
        eventsPublisher.send(.Remove(value: value, oldRange: range))
        return range
    }
    func replaceCharacters(in range: NSRange, with str: String) -> (NSRange, Int) { // changed range (could be wider than "in range"), change in length
        return (range, 0) // TOFIX
    }
    func listItemInfo(pos: Int) -> ListItemInfo? {
        return content.search(pos: pos).map{ListItemInfo(
            range: $0.0,
            depth: $0.1.depth()
        )}
    }
}

struct Node {
    enum Style {
        case dash
        case bullet
        case number
    }
    var id: Int
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
