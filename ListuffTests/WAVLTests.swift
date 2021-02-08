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
    mutating func insert(value: Value, length: Int, dir: Direction, near: Node?) -> (Node, Int)
    mutating func remove(node: Node) -> NSRange
    func setLength(node: Node, length: Int) -> NSRange
    static func same(node1: Node, node2: Node) -> Bool
    func foldLeft<T>(_ initial: T, op: (T, Value) -> T) -> T
    func foldLeftBounds<T>(_ initial: T, from: Int, to: Int?, op: (T, NSRange, Value) -> T) -> T
    func checkBalanced() -> Bool
    func getAllNodes() -> [Node]
    mutating func union(with: inout Self)
    mutating func split(node: Node) -> (Self, NSRange, Self)
    mutating func moveSuffix(to: Node, from: Node, fromContainer: Self?)
    mutating func setAsSuffix(after: Node, suffix: Self)
}

extension Partition: Sequence where Parent == () {
    func setLength(node: Node, length: Int) -> NSRange {
        return Partition.setLength(node: node, length: length)
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
        func nodeParent(node: Node?) -> Node? {
            if case .node(value: let parent) = node?.parent {
                return parent
            } else {
                return nil
            }
        }
        func checkBalance(node: Node?, level: Int) -> Bool {
            if let current = node {
                let leftNode = current[.Left]?.node
                let rightNode = current[.Right]?.node
                let leftShift = current.deep(dir: .Left) ? 2 : 1
                let rightShift = current.deep(dir: .Right) ? 2 : 1
                return (
                    (nodeParent(node: leftNode) ?? current === current) &&
                        (nodeParent(node: rightNode) ?? current === current) &&
                        (leftNode != nil || rightShift == 1) &&
                        (rightNode != nil || leftShift == 1) &&
                        (checkBalance(node: leftNode, level: level - leftShift)) &&
                        (checkBalance(node: rightNode, level: level - rightShift))
                )
            } else {
                return level == 0
            }
        }
        return nodeParent(node: root) == nil && checkBalance(node: root, level: root?.totalLengthAndRank().1 ?? 0)
    }
    func getAllNodes() -> [Node] {
        func getSubnodes(node: Node?) -> [Node] {
            if let n = node {
                return getSubnodes(node: n[.Left]?.node) + [n] + getSubnodes(node: n[.Right]?.node)
            } else {
                return []
            }
        }
        return getSubnodes(node: root)
    }
    mutating func moveSuffix(to: Node, from: Node, fromContainer: Partition<V, ()>?) {
        moveSuffix(to: to, from: from)
    }
}

final class SimpleSequence<V>: Sequence {
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
    func insert(value: V, length: Int, dir: Direction, near: Node?) -> (Node, Int) {
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
    func union(with: inout SimpleSequence<V>) {
        nodes += with.nodes
    }
    func split(node: Node) -> (SimpleSequence, NSRange, SimpleSequence) {
        if let index = (nodes.firstIndex{$0.index == node.index}) {
            let left = SimpleSequence()
            left.autoinc = autoinc
            left.nodes = Array(nodes.prefix(upTo: index))
            let right = SimpleSequence()
            right.autoinc = autoinc
            right.nodes = Array(nodes.suffix(from: nodes.index(after: index)))
            return (left, NSMakeRange(left.nodes.map{$0.length}.reduce(0){$0 + $1}, node.length), right)
        } else {
            return (self, NSMakeRange(0, 0), SimpleSequence())
        }
    }
    func getAllNodes() -> [Node] {
        return nodes
    }
    func moveSuffix(to: Node, from: Node, fromContainer: SimpleSequence<V>?) {
        guard let toIdx = (nodes.firstIndex{$0.index == to.index}) else {return}
        guard let fromIdx = ((fromContainer ?? self).nodes.firstIndex{$0.index == from.index}) else {return}
        if let fromSeq = fromContainer {
            if nodes.count > toIdx + 1 {
                nodes.removeSubrange(toIdx+1 ..< nodes.count)
            }
            if fromSeq.nodes.count > fromIdx + 1 {
                nodes.append(contentsOf: fromSeq.nodes[fromIdx + 1 ..< fromSeq.nodes.count])
            }
        } else {
            nodes.removeSubrange(toIdx+1 ... fromIdx)
        }
    }
    func setAsSuffix(after: Node, suffix: SimpleSequence<V>) {
        guard let idx = (nodes.firstIndex{$0.index == after.index}) else {return}
        if nodes.count > idx + 1 {
            nodes.removeSubrange(idx+1 ..< nodes.count)
        }
        nodes.append(contentsOf: suffix.nodes)
    }
}

enum WAVLAfterSplit {
    case Left
    case Right
    case Union
    case Reverse
}
enum WAVLCommand {
    case Search(pos: Int)
    case Insert(value: Int, length: Int, dir: Direction, near: Int) // length >= 1; near modulo (number of active nodes + 1); near = 0 means root
    case Remove(node: Int) // node module (number of active nodes + 1); node = 0 means no-op
    case SetLength(node: Int, length: Int) // node module (number of active nodes + 1); node = 0 means no-op
    case FoldPart(start: Int, length: Int?)
    case Split(node: Int, action: WAVLAfterSplit)
    case MoveSuffixSelf(node1: Int, node2: Int)
    case MoveSuffixOther(pivot: Int, node1: Int, node2: Int)
    case SplitAndSetAsSuffix(pivot: Int, after: Int)
}
class WAVLTester<S: Sequence> where S.Value == Int {
    var tree: S
    var nodes: [S.Node] = []
    init(tree: S) {
        self.tree = tree
    }
    func executeCommand(cmd: WAVLCommand) -> (NSRange, Int)? {
        switch cmd {
        case .Search(pos: let pos):
            return tree.search(pos: pos)
        case .Insert(value: let value, length: let length, dir: let dir, near: let near):
            let realLength = length >= 1 ? length : 1 - length
            let index = near % (1 + nodes.count)
            let node = index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]
            let (newNode, shift) = tree.insert(value: value, length: realLength, dir: dir, near: node)
            nodes.append(newNode)
            return (NSMakeRange(shift, length), 0)
        case .Remove(node: let node):
            let index = node % (1 + nodes.count)
            if let toRemove = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                let range = tree.remove(node: toRemove)
                nodes.removeAll{S.same(node1: $0, node2: toRemove)}
                return (range, 0)
            }
            return nil
        case .SetLength(node: let node, length: let length):
            let realLength = length >= 1 ? length : 1 - length
            let index = node % (1 + nodes.count)
            if let toChange = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                let range = tree.setLength(node: toChange, length: realLength)
                return (range, 0)
            }
            return nil
        case .FoldPart(start: let start, length: let length):
            return tree.foldLeftBounds((NSMakeRange(1, 1), 0), from: start, to: length.map {start &+ $0}) {acc, bounds, value in
                let (range, sum) = acc
                let newStart = range.location &* (1 + bounds.location)
                let newLength = range.length &* bounds.length
                return (NSMakeRange(newStart, newLength), sum &+ value)
            }
        case .Split(node: let node, action: let afterSplit):
            let index = node % (1 + nodes.count)
            if let pivot = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                var (left, range, right) = tree.split(node: pivot)
                var toRemove: [S.Node]
                switch afterSplit {
                case .Left:
                    tree = left
                    toRemove = [pivot] + right.getAllNodes()
                case .Right:
                    tree = right
                    toRemove = left.getAllNodes() + [pivot]
                case .Union:
                    tree = left
                    tree.union(with: &right)
                    toRemove = [pivot]
                case .Reverse:
                    tree = right
                    tree.union(with: &left)
                    toRemove = [pivot]
                }
                for n in toRemove {
                    nodes.removeAll{S.same(node1: $0, node2: n)}
                }
                return (range, 0)
            } else {
                return nil
            }
        case .MoveSuffixSelf(node1: let node1, node2: let node2):
            let index1 = node1 % (1 + nodes.count)
            let index2 = node2 % (1 + nodes.count)
            let fixedIndex1 = index1 == 0 ? nil : index1 > 0 ? index1 - 1 : index1 + nodes.count
            let fixedIndex2 = index2 == 0 ? nil : index2 > 0 ? index2 - 1 : index2 + nodes.count
            if let i1 = fixedIndex1, let i2 = fixedIndex2, i1 != i2 {
                let allNodes = tree.getAllNodes()
                guard let idx1 = (allNodes.firstIndex{S.same(node1: $0, node2: nodes[i1])}) else {return nil}
                guard let idx2 = (allNodes.firstIndex{S.same(node1: $0, node2: nodes[i2])}) else {return nil}
                let (fidx1, fidx2) = idx1 < idx2 ? (idx1, idx2) : (idx2, idx1)
                let toRemove = allNodes[fidx1+1...fidx2]
                tree.moveSuffix(to: allNodes[fidx1], from: allNodes[fidx2], fromContainer: nil)
                for n in toRemove {
                    nodes.removeAll{S.same(node1: $0, node2: n)}
                }
            }
            return nil
        case .MoveSuffixOther(pivot: let pivot, node1: let node1, node2: let node2):
            let index = pivot % (1 + nodes.count)
            if let pivotNode = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                let (left, _, right) = tree.split(node: pivotNode)
                var toRemove = [pivotNode]
                let leftNodes = left.getAllNodes()
                let rightNodes = right.getAllNodes()
                let index1 = node1 % (1 + leftNodes.count)
                let index2 = node2 % (1 + rightNodes.count)
                if let fixedIndex1 = (index1 == 0 ? nil : index1 > 0 ? index1-1 : index1 + leftNodes.count),
                   let fixedIndex2 = (index2 == 0 ? nil : index2 > 0 ? index2-1 : index2 + rightNodes.count) {
                    let leftNode = leftNodes[fixedIndex1]
                    let rightNode = rightNodes[fixedIndex2]
                    if fixedIndex1 < leftNodes.count - 1 {
                        toRemove.append(contentsOf: leftNodes[fixedIndex1+1 ..< leftNodes.count])
                    }
                    toRemove.append(contentsOf: rightNodes[0 ... fixedIndex2])
                    tree = left
                    tree.moveSuffix(to: leftNode, from: rightNode, fromContainer: right)
                } else {
                    tree = left
                    toRemove.append(contentsOf: rightNodes)
                }
                for n in toRemove {
                    nodes.removeAll{S.same(node1: $0, node2: n)}
                }
            }
            return nil
        case .SplitAndSetAsSuffix(pivot: let pivot, after: let after):
            let index = pivot % (1 + nodes.count)
            if let pivotNode = (index == 0 ? nil : index > 0 ? nodes[index-1] : nodes[index + nodes.count]) {
                let (left, _, right) = tree.split(node: pivotNode)
                var toRemove = [pivotNode]
                let leftNodes = left.getAllNodes()
                let afterIndex = after % (1 + leftNodes.count)
                if let fixedAfterIndex = (afterIndex == 0 ? nil : afterIndex > 0 ? afterIndex-1 : afterIndex + leftNodes.count) {
                    let afterNode = leftNodes[fixedAfterIndex]
                    if fixedAfterIndex < leftNodes.count - 1 {
                        toRemove.append(contentsOf: leftNodes[fixedAfterIndex+1 ..< leftNodes.count])
                    }
                    tree = left
                    tree.setAsSuffix(after: afterNode, suffix: right)
                } else {
                    tree = left
                    toRemove.append(contentsOf: right.getAllNodes())
                }
                for n in toRemove {
                    nodes.removeAll{S.same(node1: $0, node2: n)}
                }
            }
            return nil
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
    let tester1 = WAVLTester(tree: Partition(parent: ()))
    let tester2 = WAVLTester(tree: SimpleSequence())
    var index = 0
    for cmd in cmds {
        let val1 = tester1.executeCommand(cmd: cmd)
        let val2 = tester2.executeCommand(cmd: cmd)
        XCTAssert(tester1.tree.checkBalanced())
        let foldedTree: [(NSRange, Int)] = tester1.tree.foldLeftBounds([]){$0 + [($1, $2)]}
        var foldedNodes: [(NSRange, Int)] = []
        var start = 0
        for node in tester2.tree.nodes {
            foldedNodes.append((NSMakeRange(start, node.length), node.value))
            start += node.length
        }
        XCTAssertEqual(foldedTree.count, foldedNodes.count)
        for (node1, node2) in zip(foldedTree, foldedNodes) {
            XCTAssert(checkSame(t1: node1, t2: node2))
        }
        XCTAssertEqual(tester1.tree.foldLeft([]){$0 + [$1]}, tester2.tree.nodes.map {$0.value})
        XCTAssert(checkSame(t1: val1, t2: val2))
        index += 1
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
    switch Int.random(in: 0...8) {
    case 0:
        return .Search(pos: generatePos())
    case 1:
        let value = Int.random(in: Int.min...Int.max)
        let length = Int.random(in: 1...1000)
        let dir: Direction = Bool.random() ? .Left : .Right
        let near = Int.random(in: 0...Int.max)
        return .Insert(value: value, length: length, dir: dir, near: near)
    case 2:
        return .Remove(node: Int.random(in: Int.min...Int.max))
    case 3:
        return .SetLength(node: Int.random(in: Int.min...Int.max), length: Int.random(in: 1...1000))
    case 4:
        let start = generatePos()
        let length = Bool.random() ? generatePos() : nil
        return .FoldPart(start: start, length: length)
    case 5:
        let node = Int.random(in: 0...Int.max)
        let afterSplit: WAVLAfterSplit
        switch Int.random(in: 0...3) {
        case 0: afterSplit = .Left
        case 1: afterSplit = .Right
        case 2: afterSplit = .Union
        default: afterSplit = .Reverse
        }
        return .Split(node: node, action: afterSplit)
    case 6:
        return .MoveSuffixSelf(node1: Int.random(in: Int.min...Int.max), node2: Int.random(in: Int.min...Int.max))
    case 7:
        return .MoveSuffixOther(pivot: Int.random(in: Int.min...Int.max), node1: Int.random(in: Int.min...Int.max), node2: Int.random(in: Int.min...Int.max))
    default:
        return .SplitAndSetAsSuffix(pivot: Int.random(in: Int.min...Int.max), after: Int.random(in: Int.min...Int.max))
    }
}
func generateCmds() -> [WAVLCommand] {
    let length = Int.random(in: 0...10000)
    return (0..<length).map{_ in generateCmd()}
}

class WAVLTests: XCTestCase {
    func testRandom() throws {
//        let cmds = generateCmds()
//        try testCommands(cmds: cmds)
        var result: Error? = nil
        var hasResult = atomic_flag()
        DispatchQueue.concurrentPerform(iterations: 500) {_ in
            guard result == nil else { return }
            let cmds = generateCmds()
            do {
                try testCommands(cmds: cmds)
            } catch {
                if atomic_flag_test_and_set(&hasResult) == false {
                    result = error
                }
            }
        }
        if let error = result {
            throw error
        }
    }
}
