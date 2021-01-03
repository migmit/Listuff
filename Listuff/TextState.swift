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
    init(text: String, chunks: WAVLTree<Item>, root: Item) {
        self.string = text
        self.content = WAVLTree()
        self.document = Document.List()
    }
    init(node: Node) {
        func callback(_ content: String) -> ((Document.Line, WAVLDir, WAVLTree<Document.Line>.Node?) -> WAVLTree<Document.Line>.Node) {
            let text = content + "\n"
            self.string += text
            return {self.content.insert(value: $0, length: text.count, dir: $1, near: $2).0}
        }
        func appendSublist(list: Document.List, after: (Document.Item, Document.Line)?, nodes: [Node]) -> (Document.Item, Document.Line)? {
            guard let firstNode = nodes.first else {return nil}
            let (sublist, item) = list.insertLineSublist(checked: nil, style: nil, dir: .Right, nearLine: after?.1, nearItem: after?.0, callback: callback(firstNode.text))
            var lastInserted = (Document.Item.regular(value: item), item.content)
            lastInserted = appendSublist(list: sublist.list, after: lastInserted, nodes: firstNode.children) ?? lastInserted
            for node in nodes.suffix(from: nodes.index(after: nodes.startIndex)) {
                let insertedLine = sublist.list.insertLine(checked: nil, style: nil, dir: .Right, nearLine: lastInserted.1, nearItem: lastInserted.0, callback: callback(node.text))
                lastInserted = (Document.Item.regular(value: insertedLine), insertedLine.content)
                lastInserted = appendSublist(list: sublist.list, after: lastInserted, nodes: node.children) ?? lastInserted
            }
            return (Document.Item.sublist(value: sublist), lastInserted.1)
        }
        self.string = ""
        self.content = WAVLTree()
        self.document = Document.List()
        let firstLine = self.document.insertLine(checked: nil, style: nil, dir: .Right, nearLine: nil, nearItem: nil, callback: callback(node.text))
        _ = appendSublist(list: self.document, after: (Document.Item.regular(value: firstLine), firstLine.content), nodes: node.children)
    }
    func setChunkLength(node: Chunk, length: Int) -> NSRange {
        let range = WAVLTree.setLength(node: node, length: length)
        eventsPublisher.send(.SetLength(value: node.value, length: length, oldRange: range))
        return range
    }
//    func insertChunk(value: Item, length: Int, dir: Dir = .Right, near: Chunk? = nil) -> (Chunk, Int) {
//        let (node, start) = chunks.insert(value: value, length: length, dir: dir, near: near)
//        eventsPublisher.send(.Insert(node: node, range: NSMakeRange(start, length)))
//        return (node, start)
//    }
//    func removeChunk(node: Chunk) -> NSRange {
//        let value = node.value
//        let range = chunks.remove(node: node)
//        eventsPublisher.send(.Remove(value: value, oldRange: range))
//        return range
//    }
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
    var id: Int
    var text: String
    var children: [Node] = []
    
    func allNodes() -> [Node] {
        var result = [self]
        for child in children {
            result = result + child.allNodes()
        }
        return result
    }
}
