//
//  TextState.swift
//  Listuff
//
//  Created by MigMit on 27.12.2020.
//

import Foundation
import Combine

class TextState {
    typealias Dir = WAVLTree<Item>.Dir
    typealias Chunk = WAVLTree<Item>.Node
    typealias EventPublisher = AnyPublisher<Event, Never>
    class Item {
        var id: Int
        weak var text: WAVLTree<Item>.Node!
        var children: WAVLTree<Item> = WAVLTree()
        weak var parent: Item?
        init(id: Int, text: String, chunks: inout WAVLTree<Item>, parent: Item?) {
            self.id = id
            self.text = chunks.insert(value: self, length: text.utf16.count, dir: .Left, near: nil).0
            self.parent = parent
        }
        var depth: Int {
            var result = 0
            var current = self
            while let p = current.parent {
                result += 1
                current = p
            }
            return result
        }
    }
    enum Event {
        case Insert(node: Chunk, range: NSRange)
        case Remove(value: Item, oldRange: NSRange)
        case SetLength(value: Item, length: Int, oldRange: NSRange)
    }
    struct ListItemInfo {
        let range: NSRange
        let depth: Int
    }
    var text: String
    var chunks: WAVLTree<Item>
    var root: Item
    var items: [(Int, Substring)] {
        var result: [(Int, Substring)] = []
        for (bounds, item) in chunks {
            if let r = Range(bounds, in: text) {
                result.append((item.id, text[r]))
            }
        }
        return result
    }
    private let eventsPublisher = PassthroughSubject<Event, Never>()
    var events: EventPublisher {
        return eventsPublisher.eraseToAnyPublisher()
    }
    init(text: String, chunks: WAVLTree<Item>, root: Item) {
        self.text = text
        self.chunks = chunks
        self.root = root
    }
    init(node: Node) {
        var chunks: WAVLTree<Item> = WAVLTree()
        var text = node.text + "\n"
        var root = Item(id: node.id, text: text, chunks: &chunks, parent: nil)
        func appendChildren(current: inout Item, children: [Node]) {
            for child in children {
                let childText = child.text + "\n"
                text += childText
                var item = Item(id: child.id, text: childText, chunks: &chunks, parent: current)
                let _ = current.children.insert(value: item, length: 1, dir: .Left, near: nil)
                appendChildren(current: &item, children: child.children)
            }
        }
        appendChildren(current: &root, children: node.children)
        self.text = text
        self.chunks = chunks
        self.root = root
    }
    func setChunkLength(node: Chunk, length: Int) -> NSRange {
        let range = WAVLTree.setLength(node: node, length: length)
        eventsPublisher.send(.SetLength(value: node.value, length: length, oldRange: range))
        return range
    }
    func insertChunk(value: Item, length: Int, dir: Dir = .Right, near: Chunk? = nil) -> (Chunk, Int) {
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
        return chunks.search(pos: pos).map{ListItemInfo(
            range: $0.0,
            depth: $0.1.depth
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
