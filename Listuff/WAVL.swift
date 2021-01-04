//
//  WAVL.swift
//  Listuff
//
//  Created by MigMit on 29.11.2020.
//

import Foundation

enum WAVLDir {
    case Left
    case Right
    var other: WAVLDir {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
    static let all: [WAVLDir] = [.Left, .Right]
}
struct WAVLDirMap<V> {
    typealias Value = V
    private var left: V
    private var right: V
    subscript(dir: WAVLDir) -> V {
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
    init(dir: WAVLDir, this: V, other: V) {
        left = dir == .Left ? this : other
        right = dir == .Right ? this : other
    }
    init(calcVal: (WAVLDir) -> V) {
        left = calcVal(.Left)
        right = calcVal(.Right)
    }
}

struct WAVLTree<V>: Sequence {
    typealias Value = V
    struct SubNode {
        var deep: Bool
        let node: Node
    }
    class Node {
        let value: V
        private(set) var end: Int
        private var subnode: WAVLDirMap<SubNode?> = WAVLDirMap{_ in nil}
        private(set) var parent: Node? = nil
        init(value: V, length: Int) {
            self.value = value
            self.end = length
        }
        subscript(dir: WAVLDir) -> SubNode? {
            get {
                return subnode[dir]
            }
            set(subNode) {
                subnode[dir] = subNode
                subNode?.node.parent = self
            }
        }
        func mkSubNode(deep: Bool) -> SubNode {
            return SubNode(deep: deep, node: self)
        }
        func advance(dir: WAVLDir, length: Int) -> Int {
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
        func detach() {
            parent = nil
        }
        func getChildInfo() -> (Node, WAVLDir, Bool)? {
            return parent.map {p in
                let dir: WAVLDir = p[.Left]?.node === self ? .Left : .Right
                return (p, dir, p.deep(dir: dir))
            }
        }
        func deep(dir: WAVLDir) -> Bool { // non-encoded invariant: if self[dir] = nil, then either self is a leaf or self[dir.other] is not deep
            return self[dir]?.deep ?? (self[dir.other] != nil)
        }
        func leftmostChild() -> Node {
            var current = self
            while let child = current[.Left]?.node {current = child}
            return current
        }
        func totalLength() -> Int {
            var result = end
            var current = self
            while let sub = current[.Right]?.node {
                current = sub
                result += current.end
            }
            return result
        }
        func near(dir: WAVLDir) -> Node? {
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
    }
    private(set) var root: Node? = nil
    private(set) var rank: Int = 0
    init() {}
    private init(root: Node?, rank: Int) {
        self.root = root
        self.rank = rank
        root?.detach()
    }
    func side(dir: WAVLDir) -> Node? {
        if let r = root {
            var current = r
            while let child = current[dir]?.node {current = child}
            return current
        } else {
            return nil
        }
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
    mutating func replace(node: Node, with: Node?) {
        if let (parent, dir, isDeep) = node.getChildInfo() {
            parent[dir] = with?.mkSubNode(deep: isDeep)
        } else {
            if root === node {
                root = with
            }
            with?.detach()
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
    private mutating func insertRebalance(startWith: Node, topChild: Node, subDeep: Bool, subOtherDeep: Bool, dir: WAVLDir, length: Int) -> Int {
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
            guard let childInfo = current.getChildInfo() else {
                rank += 1
                return shift
            }
            (current, side, isDeep) = childInfo
            isOtherDeep = current.deep(dir: side.other)
        }
        if (isDeep) {
            current[side]?.deep = false
            shift += current.advance(dir: side, length: length)
            shift += WAVLTree.advanceRecurse(node: current, length: length)
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
            shift += WAVLTree.advanceRecurse(node: grandchild, length: length)
        } else {
            replace(node: current, with: child)
            shift += current.advance(dir: side, length: length - child.end)
            _ = child.advance(dir: side.other, length: current.end)
            current[side] = child[side.other]?.node.mkSubNode(deep: false)
            current[side.other]?.deep = false
            child[side.other] = current.mkSubNode(deep: false)
            shift += WAVLTree.advanceRecurse(node: child, length: length)
        }
        return shift
    }
    mutating func insert(value: V, length: Int, dir: WAVLDir = .Right, near: Node? = nil) -> (Node, Int) {
        let newNode = Node(value: value, length: length)
        guard let r = root else {
            rank = 1
            root = newNode
            return (newNode, 0)
        }
        var (current, side) = near.map {n in (n[dir]?.node).map{($0, dir.other)} ?? (n, dir)} ?? (r, dir.other)
        while let subNode = current[side]?.node {current = subNode}
        let isDeep = current.deep(dir: side)
        let isOtherDeep = current.deep(dir: side.other)
        current[side] = newNode.mkSubNode(deep: false)
        return (newNode, insertRebalance(startWith: current, topChild: newNode, subDeep: isDeep, subOtherDeep: isOtherDeep, dir: side, length: length))
    }
    mutating func remove(node: Node) -> NSRange {
        var current: Node
        var dir: WAVLDir
        var isDeep: Bool
        var length = node.end
        var shift = 0
        defer {
            node[.Left] = nil
            node[.Right] = nil
            node.detach()
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
                    rank -= 1
                    root = node[.Right]?.node
                    root?.detach()
                }
                return NSMakeRange(0, length)
            }
            (current, dir, isDeep) = childInfo
            current[dir] = node[.Right]?.node.mkSubNode(deep: isDeep)
        }
        if !isDeep && current[dir] == nil && current[dir.other] == nil {
            shift += current.advance(dir: dir, length: -length)
            guard let childInfo = current.getChildInfo() else {
                rank -= 1
                return NSMakeRange(shift, length)
            }
            (current, dir, isDeep) = childInfo
        }
        while isDeep {
            if current.deep(dir: dir.other) {
                shift += current.advance(dir: dir, length: -length)
                current[dir.other]?.deep = false
                guard let childInfo = current.getChildInfo() else {
                    rank -= 1
                    return NSMakeRange(shift, length)
                }
                (current, dir, isDeep) = childInfo
            } else {
                let child = current[dir.other]!.node
                if child.deep(dir: dir.other) {
                    if child.deep(dir: dir) {
                        shift += current.advance(dir: dir, length: -length)
                        child[dir]?.deep = false
                        child[dir.other]?.deep = false
                        guard let childInfo = current.getChildInfo() else {
                            rank -= 1
                            return NSMakeRange(shift, length)
                        }
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
                        shift += WAVLTree.advanceRecurse(node: grandchild, length: -length)
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
                    shift += WAVLTree.advanceRecurse(node: child, length: -length)
                    return NSMakeRange(shift, length)
                }
            }
        }
        current[dir]?.deep = true
        shift += current.advance(dir: dir, length: -length)
        shift += WAVLTree.advanceRecurse(node: current, length: -length)
        return NSMakeRange(shift, length)
    }
    private mutating func popLeft() -> Node? {
        guard let r = root else {return nil}
        let current = r.leftmostChild()
        _ = remove(node: current)
        return current
    }
    private static func rebalanceHook(root: Node, ranks: WAVLDirMap<Int>) -> (Node, Int) { // returned value: root rank raise
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
        let (dir, initialRank) = lrRankDiff > 0 ? (WAVLDir.Right, lRank) : (WAVLDir.Left, rRank)
        var tree = WAVLTree(root: root[dir.other]?.node, rank: initialRank) // real rank doesn't matter, we are only interested in relatives
        var curRankDiff = absRankDiff
        var isDeep: Bool
        var parent: Node
        var current = tree.root
        repeat {
            parent = current! // current.rank - other.rank == curRankDiff > 1; therefore current != nil
            _ = root.advance(dir: dir.other, length: -parent.end) // only works if dir == .Right
            isDeep = parent.deep(dir: dir)
            current = parent[dir]?.node
            curRankDiff -= isDeep ? 2 : 1
        } while curRankDiff > 1
        // current.rank - right.rank <= 1, but parent.rank - right.rank > 1, which means current.rank - right.rank> -1, so, current.rank - right.rank is one of {0, 1}
        let isOtherDeep = parent.deep(dir: dir.other)
        root[dir]?.deep = curRankDiff > 0 // which means == 1
        root[dir.other] = current?.mkSubNode(deep: false)
        /*
         * Assuming root[dir] == nil:
         * a) curRankDiff = 0; that means current == nil; both should be shallow, and that's what we get.
         * b) curRankDiff = 1; current is a leaf, it should be shallow, while root[dir] should be deep
         */
        parent[dir] = root.mkSubNode(deep: false)
        _ = tree.insertRebalance(startWith: parent, topChild: root, subDeep: isDeep, subOtherDeep: isOtherDeep, dir: dir, length: root.end) // if dir == .Right, real length doesn't matter, since dir == .Right always
        return (tree.root!, tree.rank)
    }
    private mutating func joinNode (node: Node, other: inout WAVLTree) { // node.end should be the desired length
        var size = 0
        var current = root
        while let c = current {
            size += c.end
            current = c[.Right]?.node
        }
        _ = node.advance(dir: .Left, length: size)
        node[.Left] = root?.mkSubNode(deep: false)
        node[.Right] = other.root?.mkSubNode(deep: false)
        let (newRoot, rankRaise) = WAVLTree.rebalanceHook(root: node, ranks: WAVLDirMap(dir: .Left, this: rank, other: other.rank))
        self = WAVLTree(root: newRoot, rank: rankRaise)
        other = WAVLTree()
    }
    mutating func join(value: V, length: Int, other: inout WAVLTree) -> Node {
        let newNode = Node(value: value, length: length)
        joinNode(node: newNode, other: &other)
        return newNode
    }
    mutating func union(with: inout WAVLTree) {
        if let node = with.popLeft() {
            joinNode(node: node, other: &with)
        } // no else, since it means `with` is empty, and we shouldn't do anything
    }
    mutating func split(node: Node) -> (WAVLTree, NSRange, WAVLTree) {
        defer {
            node[.Left] = nil
            node[.Right] = nil
            node.detach()
        }
        var results = WAVLDirMap {node[$0]?.node}
        var ranks = WAVLDirMap {node.deep(dir: $0) ? -2 : -1}
        var current = node
        var shift = node.end
        var childInfo = node.getChildInfo()
        let oldRank = rank
        let length = shift - (results[.Left]?.totalLength() ?? 0)
        while let (parent, dir, isDeep) = childInfo {
            current = parent
            childInfo = current.getChildInfo()
            for d in WAVLDir.all {ranks[d] -= isDeep ? 2 : 1}
            shift += current.advance(dir: dir, length: -shift)
            let isOtherDeep = current.deep(dir: dir.other)
            current[dir] = results[dir.other]?.mkSubNode(deep: false)
            (results[dir.other], ranks[dir.other]) = WAVLTree.rebalanceHook(root: current, ranks: WAVLDirMap(dir: dir, this: ranks[dir.other], other: isOtherDeep ? -2 : -1))
        }
        if current === root {self = WAVLTree()}
        return (WAVLTree(root: results[.Left], rank: oldRank + ranks[.Left]), NSMakeRange(shift - length, length), WAVLTree(root: results[.Right], rank: oldRank + ranks[.Right]))
    }
}
