//
//  WAVL.swift
//  Listuff
//
//  Created by MigMit on 29.11.2020.
//

import Foundation

enum Direction {
    case Left
    case Right
    var other: Direction {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
    static let all: [Direction] = [.Left, .Right]
}
struct DirectionMap<V> {
    typealias Value = V
    private var left: V
    private var right: V
    subscript(dir: Direction) -> V {
        get {
            switch dir {
            case .Left: return left
            case .Right: return right
            }
        }
        set(value) {
            switch dir {
            case .Left: left = value
            case .Right: right = value
            }
        }
    }
    init(dir: Direction, this: V, other: V) {
        left = dir == .Left ? this : other
        right = dir == .Right ? this : other
    }
    init(calcVal: (Direction) -> V) {
        left = calcVal(.Left)
        right = calcVal(.Right)
    }
}

struct Partition<V, P>: Sequence {
    typealias Value = V
    typealias Parent = P
    struct SubNode {
        var deep: Bool
        let node: Node
    }
    enum NodeOrParent {
        case node(value: Node)
        case parent(value: Parent)
    }
    class Node {
        let value: V
        private(set) var end: Int
        private var subnode: DirectionMap<SubNode?> = DirectionMap{_ in nil}
        private(set) var parent: NodeOrParent
        init(value: V, length: Int, parent: Parent) {
            self.value = value
            self.end = length
            self.parent = .parent(value: parent)
        }
        subscript(dir: Direction) -> SubNode? {
            get {
                return subnode[dir]
            }
            set(subNode) {
                subnode[dir] = subNode
                subNode?.node.parent = .node(value: self)
            }
        }
        func mkSubNode(deep: Bool) -> SubNode {
            return SubNode(deep: deep, node: self)
        }
        func advance(dir: Direction, length: Int) -> Int {
            switch dir {
            case .Left:
                end += length
                return 0
            case .Right:
                return end
            }
        }
        func copyEnd(other: Node) {
            end = other.end
        }
        func detach(parent: Parent) {
            self.parent = .parent(value: parent)
        }
        func getChildInfo() -> (Node, Direction, Bool)? {
            switch parent {
            case .node(value: let p):
                let dir: Direction = p[.Left]?.node === self ? .Left : .Right
                return (p, dir, p.deep(dir: dir))
            case .parent(value: _):
                return nil
            }
        }
        func deep(dir: Direction) -> Bool { // non-encoded invariant: if self[dir] = nil, then either self is a leaf or self[dir.other] is not deep
            return self[dir]?.deep ?? (self[dir.other] != nil)
        }
        func leftmostChild() -> Node {
            var current = self
            while let child = current[.Left]?.node {current = child}
            return current
        }
        func totalLengthAndRank() -> (Int, Int) {
            var len = end
            var current = self
            var rank = current.deep(dir: .Right) ? 2 : 1
            while let sub = current[.Right]?.node {
                current = sub
                len += current.end
                rank += current.deep(dir: .Right) ? 2 : 1
            }
            return (len, rank)
        }
        func totalLength() -> Int {
            totalLengthAndRank().0
        }
        func near(dir: Direction) -> Node? {
            if let n = self[dir]?.node {
                var current = n
                while let child = current[dir.other] {current = child.node}
                return current
            } else {
                var childInfo = getChildInfo()
                while let (parent, d, _) = childInfo {
                    if d == dir.other {return parent}
                    childInfo = parent.getChildInfo()
                }
                return nil
            }
        }
        var range: NSRange {
            let leftLength = self[.Left]?.node.totalLength() ?? 0
            var result = 0
            var current = self
            while let (parent, dir, _) = current.getChildInfo() {
                if dir == .Right {
                    result += parent.end
                }
                current = parent
            }
            return NSMakeRange(result + leftLength, end - leftLength)
        }
        var partitionParent: Parent {
            var current = self
            while(true) {
                switch current.parent {
                case .node(value: let node): current = node
                case .parent(value: let result): return result
                }
            }
        }
    }
    private(set) var root: Node? = nil
    private var parent: Parent
    init(parent: Parent) {
        self.parent = parent
    }
    private init(root: Node?, parent: Parent) {
        self.root = root
        self.parent = parent
        root?.detach(parent: parent)
    }
    private func searchNode(pos: Int) -> (NSRange, Node)? {
        var shift = 0
        var found: (Int, Node)? = nil
        var current = root
        while let node = current {
            let absoluteEnd = shift + node.end
            if pos >= absoluteEnd {
                shift = absoluteEnd
                current = node[.Right]?.node
            } else {
                current = node[.Left]?.node
                found = (absoluteEnd, node)
            }
        }
        return found.map {return (NSMakeRange(shift, $0.0 - shift), $0.1)}
    }
    struct Iterator: Sequence, IteratorProtocol {
        var nextInfo: (NSRange, Node)?
        let to: Int?
        init(nextInfo: (NSRange, Node)?, to: Int?) {
            self.nextInfo = nextInfo
            self.to = to
        }
        mutating func next() -> (NSRange, V)? {
            guard let (nextRange, nextNode) = nextInfo, (to.map{$0 > nextRange.location} ?? true) else {return nil}
            let result = (nextRange, nextNode.value)
            let rangeEnd = nextRange.location + nextRange.length
            if let child = nextNode[.Right]?.node {
                let newNode = child.leftmostChild()
                nextInfo = (NSMakeRange(rangeEnd, newNode.end), newNode)
            } else {
                var shift = 0
                var cameFromRight = true
                var newNode = nextNode
                while cameFromRight, let (parent, dir, _) = newNode.getChildInfo() {
                    shift += newNode.end
                    newNode = parent
                    cameFromRight = dir == .Right
                }
                nextInfo = cameFromRight ? nil : (NSMakeRange(rangeEnd, newNode.end - shift), newNode)
            }
            return result
        }
    }
    func covering(from: Int = 0, to: Int? = nil) -> Iterator {
        return Iterator(nextInfo: searchNode(pos: from), to: to)
    }
    func makeIterator() -> Iterator {
        return covering()
    }
    func search(pos: Int) -> (NSRange, V)? {
        return searchNode(pos: pos).map {($0.0, $0.1.value)}
    }
    func totalLength() -> Int {
        return root?.totalLength() ?? 0
    }
    func isEmpty() -> Bool {
        return root == nil
    }
    func sideValue(dir: Direction) -> V? {
        guard let r = root else {return nil}
        var current = r
        var child = current[dir]?.node
        while let c = child {
            current = c
            child = current[dir]?.node
        }
        return current.value
    }
    mutating func replace(node: Node, with: Node?) {
        if let (parent, dir, isDeep) = node.getChildInfo() {
            parent[dir] = with?.mkSubNode(deep: isDeep)
        } else {
            if root === node {
                root = with
            }
            with?.detach(parent: parent)
        }
    }
    static func advanceRecurse(node: Node, length: Int) -> Int {
        var current = node
        var result = 0
        while let (parent, dir, _) = current.getChildInfo() {
            result += parent.advance(dir: dir, length: length)
            current = parent
        }
        return result
    }
    static func setLength(node: Node, length: Int) -> NSRange {
        let shift = node[.Left]?.node.totalLength() ?? 0
        let oldLength = node.end - shift
        let advance = length - oldLength
        _ = node.advance(dir: .Left, length: advance)
        return NSMakeRange(shift + advanceRecurse(node: node, length: advance), oldLength)
    }
    private mutating func insertRebalance(startWith: Node, topChild: Node, subDeep: Bool, subOtherDeep: Bool, dir: Direction, length: Int) -> (Int, Bool) { // node left shift, was it raised?
        var current = startWith
        var child = topChild
        var isDeep = subDeep
        var isOtherDeep = subOtherDeep
        var side = dir
        var shift = 0
        while !isDeep && !isOtherDeep {
            child = current
            current[side.other]?.deep = true
            shift += current.advance(dir: side, length: length)
            guard let childInfo = current.getChildInfo() else {return (shift, true)}
            (current, side, isDeep) = childInfo
            isOtherDeep = current.deep(dir: side.other)
        }
        if (isDeep) {
            current[side]?.deep = false
            shift += current.advance(dir: side, length: length)
            shift += Partition.advanceRecurse(node: current, length: length)
        } else if (child.deep(dir: side)) {
            let grandchild = child[side.other]!.node // if child[side.other] = nil, then child is a leaf (then child.deep(_) = false) or child[side] is a leaf (then child.deep(side) = false)
            replace(node: current, with: grandchild)
            _ = grandchild.advance(dir: side, length: child.end)
            shift += current.advance(dir: side, length: length - grandchild.end)
            _ = child.advance(dir: side.other, length: -grandchild.end)
            _ = grandchild.advance(dir: side.other, length: current.end)
            child[side]?.deep = false
            child[side.other] = grandchild[side]
            current[side] = grandchild[side.other]
            current[side.other]?.deep = false
            grandchild[side] = child.mkSubNode(deep: false)
            grandchild[side.other] = current.mkSubNode(deep: false)
            shift += Partition.advanceRecurse(node: grandchild, length: length)
        } else {
            replace(node: current, with: child)
            shift += current.advance(dir: side, length: length - child.end)
            _ = child.advance(dir: side.other, length: current.end)
            current[side] = child[side.other]?.node.mkSubNode(deep: false)
            current[side.other]?.deep = false
            child[side.other] = current.mkSubNode(deep: false)
            shift += Partition.advanceRecurse(node: child, length: length)
        }
        return (shift, false)
    }
    mutating func insert(value: V, length: Int, dir: Direction = .Right, near: Node? = nil) -> (Node, Int) {
        let newNode = Node(value: value, length: length, parent: parent)
        guard let r = root else {
            root = newNode
            return (newNode, 0)
        }
        var (current, side) = near.map {n in (n[dir]?.node).map{($0, dir.other)} ?? (n, dir)} ?? (r, dir.other)
        while let subNode = current[side]?.node {current = subNode}
        let isDeep = current.deep(dir: side)
        let isOtherDeep = current.deep(dir: side.other)
        current[side] = newNode.mkSubNode(deep: false)
        return (newNode, insertRebalance(startWith: current, topChild: newNode, subDeep: isDeep, subOtherDeep: isOtherDeep, dir: side, length: length).0)
    }
    mutating func remove(node: Node) -> NSRange {
        var current: Node
        var dir: Direction
        var isDeep: Bool
        var length = node.end
        var shift = 0
        defer {
            node[.Left] = nil
            node[.Right] = nil
            node.detach(parent: parent)
        }
        if let leftSubNode = node[.Left] {
            var target = leftSubNode.node
            var targetParent = node
            while let subTarget = target[.Right]?.node {
                length -= target.end
                targetParent = target
                target = subTarget
            }
            length -= target.end
            if (targetParent === node) {
                current = target
                dir = .Left
                isDeep = leftSubNode.deep
                target[.Left]?.deep = isDeep
            } else {
                current = targetParent
                dir = .Right
                isDeep = targetParent.deep(dir: .Right)
                targetParent[.Right] = target[.Left]?.node.mkSubNode(deep: isDeep)
                target[.Left] = node[.Left]
            }
            shift = target.end
            target[.Right] = node[.Right]
            target.copyEnd(other: node)
            replace(node: node, with: target)
        } else {
            guard let childInfo = node.getChildInfo() else {
                if root === node {
                    root = node[.Right]?.node
                    root?.detach(parent: parent)
                }
                return NSMakeRange(0, length)
            }
            (current, dir, isDeep) = childInfo
            current[dir] = node[.Right]?.node.mkSubNode(deep: isDeep)
        }
        if !isDeep && current[dir] == nil && current[dir.other] == nil {
            shift += current.advance(dir: dir, length: -length)
            guard let childInfo = current.getChildInfo() else {return NSMakeRange(shift, length)}
            (current, dir, isDeep) = childInfo
        }
        while isDeep {
            if current.deep(dir: dir.other) {
                shift += current.advance(dir: dir, length: -length)
                current[dir.other]?.deep = false
                guard let childInfo = current.getChildInfo() else {return NSMakeRange(shift, length)}
                (current, dir, isDeep) = childInfo
            } else {
                let child = current[dir.other]!.node
                if child.deep(dir: dir.other) {
                    if child.deep(dir: dir) {
                        shift += current.advance(dir: dir, length: -length)
                        child[dir]?.deep = false
                        child[dir.other]?.deep = false
                        guard let childInfo = current.getChildInfo() else {return NSMakeRange(shift, length)}
                        (current, dir, isDeep) = childInfo
                    } else {
                        let grandchild = child[dir]!.node
                        replace(node: current, with: grandchild)
                        shift += current.advance(dir: dir, length: -length)
                        _ = child.advance(dir: dir, length: -grandchild.end)
                        _ = grandchild.advance(dir: dir, length: current.end)
                        _ = grandchild.advance(dir: dir.other, length: child.end)
                        _ = current.advance(dir: dir.other, length: -grandchild.end)
                        current[dir]?.deep = false
                        current[dir.other] = grandchild[dir]
                        child[dir] = grandchild[dir.other]
                        child[dir.other]?.deep = false
                        grandchild[dir] = current.mkSubNode(deep: true)
                        grandchild[dir.other] = child.mkSubNode(deep: true)
                        shift += Partition.advanceRecurse(node: grandchild, length: -length)
                        return NSMakeRange(shift, length)
                    }
                } else {
                    replace(node: current, with: child)
                    shift += current.advance(dir: dir, length: -length)
                    _ = child.advance(dir: dir, length: current.end)
                    _ = current.advance(dir: dir.other, length: -child.end)
                    current[dir.other] = child[dir]
                    child[dir.other]?.deep = true
                    child[dir] = current.mkSubNode(deep: current[.Left] == nil && current[.Right] == nil)
                    shift += Partition.advanceRecurse(node: child, length: -length)
                    return NSMakeRange(shift, length)
                }
            }
        }
        current[dir]?.deep = true
        shift += current.advance(dir: dir, length: -length)
        shift += Partition.advanceRecurse(node: current, length: -length)
        return NSMakeRange(shift, length)
    }
    private mutating func popLeft() -> Node? {
        guard let r = root else {return nil}
        let current = r.leftmostChild()
        _ = remove(node: current)
        return current
    }
    private static func rebalanceHook(root: Node, ranks: DirectionMap<Int>, parent: Parent) -> (Node, Int) { // returned value: root rank
        let lRank = ranks[.Left]
        let rRank = ranks[.Right]
        let lrRankDiff = lRank - rRank
        let absRankDiff = abs(lrRankDiff)
        if absRankDiff <= 1 {
            let maxRank = Swift.max(lRank, rRank)
            root[.Left]?.deep = lRank < maxRank
            root[.Right]?.deep = rRank < maxRank
            return (root, maxRank + 1)
        }
        let (dir, initialRank) = lrRankDiff > 0 ? (Direction.Right, lRank) : (Direction.Left, rRank)
        var tree = Partition(root: root[dir.other]?.node, parent: parent)
        var curRankDiff = absRankDiff
        var isDeep: Bool
        var parentNode: Node
        var current = tree.root
        repeat {
            parentNode = current! // current.rank - other.rank == curRankDiff > 1; therefore current != nil
            _ = root.advance(dir: dir.other, length: -parentNode.end) // only works if dir == .Right
            isDeep = parentNode.deep(dir: dir)
            current = parentNode[dir]?.node
            curRankDiff -= isDeep ? 2 : 1
        } while curRankDiff > 1
        // current.rank - right.rank <= 1, but parent.rank - right.rank > 1, which means current.rank - right.rank> -1, so, current.rank - right.rank is one of {0, 1}
        let isOtherDeep = parentNode.deep(dir: dir.other)
        root[dir]?.deep = curRankDiff > 0 // which means == 1
        root[dir.other] = current?.mkSubNode(deep: false)
        /*
         * Assuming root[dir] == nil:
         * a) curRankDiff = 0; that means current == nil; both should be shallow, and that's what we get.
         * b) curRankDiff = 1; current is a leaf, it should be shallow, while root[dir] should be deep
         */
        parentNode[dir] = root.mkSubNode(deep: false)
        let rankRaised = tree.insertRebalance(startWith: parentNode, topChild: root, subDeep: isDeep, subOtherDeep: isOtherDeep, dir: dir, length: root.end).1 // if dir == .Right, real length doesn't matter, since dir == .Right always
        return (tree.root!, initialRank + (rankRaised ? 1 : 0))
    }
    private mutating func joinNode (node: Node, other: inout Partition) { // node.end should be the desired length
        let (size, thisRank) = root?.totalLengthAndRank() ?? (0, 0)
        _ = node.advance(dir: .Left, length: size)
        node[.Left] = root?.mkSubNode(deep: false)
        node[.Right] = other.root?.mkSubNode(deep: false)
        node.detach(parent: parent)
        let otherRank = other.root?.totalLengthAndRank().1 ?? 0
        let newRoot = Partition.rebalanceHook(root: node, ranks: DirectionMap(dir: .Left, this: thisRank, other: otherRank), parent: parent).0
        self = Partition(root: newRoot, parent: parent)
        other = Partition(parent: other.parent)
    }
    mutating func join(value: V, length: Int, other: inout Partition) -> Node {
        let newNode = Node(value: value, length: length, parent: parent)
        joinNode(node: newNode, other: &other)
        return newNode
    }
    mutating func union(with: inout Partition) {
        if let node = with.popLeft() {
            joinNode(node: node, other: &with)
        } // no else, since it means `with` is empty, and we shouldn't do anything
    }
    mutating func split(node: Node) -> (Partition, NSRange, Partition) {
        defer {
            node[.Left] = nil
            node[.Right] = nil
            node.detach(parent: parent)
        }
        var results = DirectionMap {node[$0]?.node}
        let (leftLength, leftRank) = results[.Left]?.totalLengthAndRank() ?? (0, 0)
        var currentRank = leftRank + (node.deep(dir: .Left) ? 2 : 1)
        var ranks = DirectionMap(dir: .Left, this: leftRank, other: currentRank - (node.deep(dir: .Right) ? 2 : 1))
        var current = node
        var childInfo = node.getChildInfo()
        let length = node.end - leftLength
        var shift = leftLength
        while let (parent, dir, isDeep) = childInfo {
            current = parent
            currentRank += isDeep ? 2 : 1
            childInfo = current.getChildInfo()
            shift += current.advance(dir: dir, length: -shift - length)
            let isOtherDeep = current.deep(dir: dir.other)
            current[dir] = results[dir.other]?.mkSubNode(deep: false)
            (results[dir.other], ranks[dir.other]) = Partition.rebalanceHook(root: current, ranks: DirectionMap(dir: dir, this: ranks[dir.other], other: currentRank - (isOtherDeep ? 2 : 1)), parent: self.parent)
        }
        if current === root {self = Partition(parent: self.parent)}
        return (Partition(root: results[.Left], parent: self.parent), NSMakeRange(shift, length), Partition(root: results[.Right], parent: self.parent))
    }
    mutating func retarget(newParent: Parent) {
        parent = newParent
        root?.detach(parent: newParent)
    }
    mutating func moveSuffix(to: Node, from: Node) { // if they are from the same partition, `from` should be after `to`
        let args = DirectionMap(dir: .Left, this: to, other: from)
        let toRank = to.totalLengthAndRank().1
        let fromRank = from.totalLengthAndRank().1
        let startSide = toRank >= fromRank ? Direction.Right : Direction.Left
        var lengthAddition = toRank >= fromRank ? 0 : to.end - from.end
        var sides = DirectionMap(dir: startSide, this: nil, other: to)
        var sideRanks: DirectionMap<Int> = DirectionMap(dir: .Left, this: toRank, other: fromRank)
        var result = args[startSide][startSide]?.node
        var resultRank = sideRanks[startSide] - (args[startSide].deep(dir: startSide) ? 2 : 1)
        var candidate = args[startSide]
        while let (parentNode, dir, isDeep) = candidate.getChildInfo() {
            lengthAddition -= candidate.advance(dir: startSide, length: 0)
            candidate = parentNode
            sideRanks[startSide] += isDeep ? 2 : 1
            if dir == startSide.other {
                sides[startSide] = candidate
                break
            }
        }
        if toRank < fromRank {
            if let (thisParent, thisDir, _) = to.getChildInfo() {
                thisParent[thisDir] = nil
            }
            to[.Left] = from[.Left]
            to[.Right] = from[.Right]
            if let (otherParent, otherDir, otherIsDeep) = from.getChildInfo() {
                otherParent[otherDir] = to.mkSubNode(deep: otherIsDeep)
            } else {
                to.detach(parent: parent)
            }
            _ = to.advance(dir: .Left, length: -lengthAddition)
        }
        while true {
            let preLoopSide = sideRanks[.Left] <= sideRanks[.Right] ? Direction.Left : Direction.Right
            guard let loopNode = sides[preLoopSide] ?? sides[preLoopSide.other] else {break}
            let loopSide = sides[preLoopSide] == nil ? preLoopSide.other : preLoopSide
            lengthAddition += loopNode.advance(dir: loopSide.other, length: lengthAddition)
            let ranks = DirectionMap(dir: loopSide, this: loopNode[loopSide] == nil ? 0 : sideRanks[loopSide] - (loopNode.deep(dir: loopSide) ? 2 : 1), other: resultRank)
            sides[loopSide] = nil
            var candidate = loopNode
            while let (parentNode, dir, isDeep) = candidate.getChildInfo() {
                candidate = parentNode
                sideRanks[loopSide] += isDeep ? 2 : 1
                if dir == loopSide.other {
                    sides[loopSide] = candidate
                    break
                }
                lengthAddition -= candidate.advance(dir: loopSide, length: 0)
            }
            loopNode[loopSide.other] = result?.mkSubNode(deep: false)
            (result, resultRank) = Partition.rebalanceHook(root: loopNode, ranks: ranks, parent: parent)
        }
        self = Partition(root: result, parent: parent)
    }
    func debugPrintNode(nodeOpt: Node?, prefix: String) {
        guard let node = nodeOpt else {
            print(prefix)
            return
        }
        if let leftNode = node[.Left] {
            debugPrintNode(nodeOpt: leftNode.node, prefix: prefix + (leftNode.deep ? " ." : " "))
        }
        print("\(prefix)\(node.value) [\(node.end)]")
        if let rightNode = node[.Right] {
            debugPrintNode(nodeOpt: rightNode.node, prefix: prefix + (rightNode.deep ? " ." : " "))
        }
    }
    func debugPrint() {
        debugPrintNode(nodeOpt: root, prefix: "")
    }
}
