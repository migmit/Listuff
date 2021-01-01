//
//  WAVLTests.swift
//  ListuffTests
//
//  Created by MigMit on 29.11.2020.
//

import XCTest
@testable import Listuff

protocol Sequence {
    associatedtype Value
    associatedtype Node
    func search(pos: Int) -> (NSRange, Value)?
    mutating func insert(value: Value, length: Int, dir: WAVLTree<Value>.WAVLDir, near: Node?) -> (Node, Int)
    mutating func remove(node: Node) -> NSRange
    func setLength(node: Node, length: Int) -> NSRange
    static func same(node1: Node, node2: Node) -> Bool
    func foldLeft<T>(_ initial: T, op: (T, Value) -> T) -> T
    func foldLeftBounds<T>(_ initial: T, from: Int, to: Int?, op: (T, NSRange, Value) -> T) -> T
    func checkBalanced() -> Bool
}

extension WAVLTree: Sequence {
    func setLength(node: Node, length: Int) -> NSRange {
        return WAVLTree.setLength(node: node, length: length)
    }
    static func same(node1: Node, node2: Node) -> Bool {
        return node1 === node2
    }
    func foldLeft<T>(_ initial: T, op: (T, Value) -> T) -> T {
        var result = initial
        for (_, v) in self {
            result = op(result, v)
        }
        return result
    }
    func foldLeftBounds<T>(_ initial: T, from: Int = 0, to: Int? = nil, op: (T, NSRange, Value) -> T) -> T {
        var result = initial
        for (r, v) in covering(from: from, to: to) {
            result = op(result, r, v)
        }
        return result
    }
    func checkBalanced() -> Bool {
        func checkBalance(node: Node?, level: Int) -> Bool {
            if let current = node {
                let leftNode = current[.Left]?.node
                let rightNode = current[.Right]?.node
                let leftShift = current.deep(dir: .Left) ? 2 : 1
                let rightShift = current.deep(dir: .Right) ? 2 : 1
                return (
                    (leftNode?.parent ?? current === current) &&
                    (rightNode?.parent ?? current === current) &&
                    (leftNode != nil || rightShift == 1) &&
                    (rightNode != nil || leftShift == 1) &&
                    (checkBalance(node: leftNode, level: level - leftShift)) &&
                    (checkBalance(node: rightNode, level: level - rightShift))
                )
            } else {
                return level == 0
            }
        }
        return checkBalance(node: root, level: rank)
    }
}

class SimpleSequence<V>: Sequence {
    typealias Value = V
    class Node {
        let index: Int
        var length: Int
        let value: V
        init(index: Int, length: Int, value: V) {
            self.index = index
            self.length = length
            self.value = value
        }
    }
    var nodes: [Node] = []
    var autoinc: Int = 0
    func search(pos: Int) -> (NSRange, V)? {
        var shift = 0
        for node in nodes {
            let newShift = shift + node.length
            if pos < newShift {
                return (NSMakeRange(shift, node.length), node.value)
            } else {
                shift = newShift
            }
        }
        return nil
    }
    func setLength(node: Node, length: Int) -> NSRange {
        var shift = 0
        for current in nodes {
            if current.index == node.index {break}
            shift += current.length
        }
        let result = NSMakeRange(shift, node.length)
        node.length = length
        return result
    }
    func insert(value: V, length: Int, dir: WAVLTree<V>.WAVLDir, near: Node?) -> (Node, Int) {
        var pos: Int
        if let n = near, let p = (nodes.firstIndex{$0.index == n.index}) {
            switch dir {
            case .Left: pos = p
            case .Right: pos = p+1
            }
        } else {
            switch dir {
            case .Left: pos = nodes.count
            case .Right: pos = 0
            }
        }
        let newNode = Node(index: autoinc, length: length, value: value)
        nodes.insert(newNode, at: pos)
        var shift = 0
        for node in nodes {
            if node.index == autoinc {break}
            shift += node.length
        }
        autoinc += 1
        return (newNode, shift)
    }
    func remove(node: Node) -> NSRange {
        var shift = 0
        let length = node.length
        for current in nodes {
            if current.index == node.index {break}
            shift += current.length
        }
        nodes.removeAll{$0.index == node.index}
        return NSMakeRange(shift, length)
    }
    static func same(node1: Node, node2: Node) -> Bool {
        return node1.index == node2.index
    }
    func foldLeft<T>(_ initial: T, op: (T, Value) -> T) -> T {
        var result = initial
        for node in nodes {
            result = op(result, node.value)
        }
        return result
    }
    func foldLeftBounds<T>(_ initial: T, from: Int, to: Int?, op: (T, NSRange, Value) -> T) -> T {
        var result = initial
        var pos = 0
        for node in nodes {
            let newPos = pos + node.length
            if newPos > from && (to.map {pos < $0} ?? true) {
                result = op(result, NSMakeRange(pos, node.length), node.value)
            }
            pos = newPos
        }
        return result
    }
    func checkBalanced() -> Bool {
        return true
    }
}

enum WAVLCommand {
    case Search(pos: Int)
    case Insert(value: Int, length: Int, dir: WAVLTree<Int>.WAVLDir, near: Int) // length >= 1; near modulo (number of active nodes + 1); near = 0 means root
    case Remove(node: Int) // node module (number of active nodes + 1); node = 0 means no-op
    case SetLength(node: Int, length: Int) // node module (number of active nodes + 1); node = 0 means no-op
    case FoldPart(start: Int, length: Int?)
}
class WAVLTester<S: Sequence> where S.Value == Int {
    var tree: S
    var nodes: [S.Node] = []
    init(tree: S) {
        self.tree = tree
    }
    func executeCommand(cmd: WAVLCommand) -> (NSRange, Int)? {
        switch cmd {
        case .Search(let pos):
            return tree.search(pos: pos)
        case .Insert(let value, let length, let dir, let near):
            let realLength = length >= 1 ? length : 1 - length
            let index = near % (1 + nodes.count)
            let node = index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]
            let (newNode, shift) = tree.insert(value: value, length: realLength, dir: dir, near: node)
            nodes.append(newNode)
            return (NSMakeRange(shift, length), 0)
        case .Remove(let node):
            let index = node % (1 + nodes.count)
            if let toRemove = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                let range = tree.remove(node: toRemove)
                nodes.removeAll{S.same(node1: $0, node2: toRemove)}
                return (range, 0)
            }
            return nil
        case .SetLength(let node, let length):
            let realLength = length >= 1 ? length : 1 - length
            let index = node % (1 + nodes.count)
            if let toChange = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                let range = tree.setLength(node: toChange, length: realLength)
                return (range, 0)
            }
            return nil
        case .FoldPart(let start, let length):
            return tree.foldLeftBounds((NSMakeRange(1, 1), 0), from: start, to: length.map {start &+ $0}) {acc, bounds, value in
                let (range, sum) = acc
                let newStart = range.location &* (1 + bounds.location)
                let newLength = range.length &* bounds.length
                return (NSMakeRange(newStart, newLength), sum &+ value)
            }
        }
    }
}
func checkSame(t1: (NSRange, Int)?, t2: (NSRange, Int)?) -> Bool {
    if let (r1, v1) = t1 {
        guard let (r2, v2) = t2 else {return false}
        return NSEqualRanges(r1, r2) && v1 == v2
    } else {
        return t2 == nil
    }
}
func testCommands(cmds: [WAVLCommand]) throws {
    let tester1 = WAVLTester(tree: WAVLTree())
    let tester2 = WAVLTester(tree: SimpleSequence())
    for cmd in cmds {
        let val1 = tester1.executeCommand(cmd: cmd)
        let val2 = tester2.executeCommand(cmd: cmd)
        XCTAssert(tester1.tree.checkBalanced())
        XCTAssertEqual(tester1.tree.foldLeft([]){$0 + [$1]}, tester2.tree.nodes.map {$0.value})
        XCTAssert(checkSame(t1: val1, t2: val2))
    }
}
func generatePos() -> Int {
    switch Int.random(in: 0...10) {
    case 0: return 0
    case 1: return Int.random(in: 1...100)
    case 2: return Int.random(in: 101...1000)
    case 3: return Int.random(in: 1001...10000)
    case 4: return Int.random(in: 10001...100000)
    case 5: return Int.random(in: 100001...1000000)
    case 6: return Int.random(in: 1000001...10000000)
    case 7: return Int.random(in: 10000001...100000000)
    case 8: return Int.random(in: 100000001...1000000000)
    case 9: return Int.random(in: 1000000001...10000000000)
    default: return Int.random(in: 10000000001...Int.max)
    }
}
func generateCmd() -> WAVLCommand {
    switch Int.random(in: 0...4) {
    case 0:
        return .Search(pos: generatePos())
    case 1:
        let value = Int.random(in: Int.min...Int.max)
        let length = Int.random(in: 1...1000)
        let dir: WAVLTree<Int>.WAVLDir = Bool.random() ? .Left : .Right
        let near = Int.random(in: 0...Int.max)
        return .Insert(value: value, length: length, dir: dir, near: near)
    case 2:
        return .Remove(node: Int.random(in: Int.min...Int.max))
    case 3:
        return .SetLength(node: Int.random(in: Int.min...Int.max), length: Int.random(in: 1...1000))
    default:
        let start = generatePos()
        let length = Bool.random() ? generatePos() : nil
        return .FoldPart(start: start, length: length)
    }
}
func generateCmds() -> [WAVLCommand] {
    let length = Int.random(in: 0...1000)
    return (0..<length).map{_ in generateCmd()}
}

class WAVLTests: XCTestCase {
    func testRandom() throws {
        for _ in 1...100 {
            let cmds = generateCmds()
            try testCommands(cmds: cmds)
        }
    }
}
