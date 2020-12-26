//
//  WAVL.swift
//  Listuff
//
//  Created by MigMit on 29.11.2020.
//

import Foundation

struct WAVLTree<V>: Sequence {
    enum Dir {
        case Left
        case Right
        var other: Dir {
            switch self {
            case .Left: return .Right
            case .Right: return .Left
            }
        }
    }
    typealias Value = V
    struct SubNode {
        var deep: Bool
        let node: Node
    }
    class Node {
        let value: V
        private(set) var end: Int
        private var left: SubNode? = nil
        private var right: SubNode? = nil
        private(set) var parent: Node? = nil
        init(value: V, length: Int) {
            self.value = value
            self.end = length
        }
        subscript(dir: Dir) -> SubNode? {
            get {
                switch dir {
                case .Left: return left
                case .Right: return right
                }
            }
            set(subNode) {
                switch dir {
                case .Left: left = subNode
                case .Right: right = subNode
                }
                subNode?.node.parent = self
            }
        }
        func mkSubNode(deep: Bool) -> SubNode {
            return SubNode(deep: deep, node: self)
        }
        func advance(dir: Dir, length: Int) -> Int {
            switch(dir) {
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
        func getChildInfo() -> (Node, Dir, Bool)? {
            return parent.map {p in
                let dir: Dir = p[.Left]?.node === self ? .Left : .Right
                return (p, dir, p.deep(dir: dir))
            }
        }
        func deep(dir: Dir) -> Bool { // non-encoded invariant: if self[dir] = nil, then either self is a leaf or self[dir.other] is not deep
            return self[dir]?.deep ?? (self[dir.other] != nil)
        }
        func leftmostChild() -> Node {
            var current = self
            while let child = current[.Left]?.node {current = child}
            return current
        }
    }
    private(set) var root: Node? = nil
    init() {}
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
        var shift = 0
        var subNode = node[.Left]?.node
        while let child = subNode {
            shift += child.end
            subNode = child[.Right]?.node
        }
        let oldLength = node.end - shift
        let advance = length - oldLength
        _ = node.advance(dir: .Left, length: advance)
        shift += advanceRecurse(node: node, length: advance)
        return NSMakeRange(shift, oldLength)
    }
    mutating func insert(value: V, length: Int, dir: Dir = .Right, near: Node? = nil) -> (Node, Int) {
        let newNode = Node(value: value, length: length)
        guard let r = root else {
            root = newNode
            return (newNode, 0)
        }
        var (current, side) = near.map {n in (n[dir]?.node).map{($0, dir.other)} ?? (n, dir)} ?? (r, dir.other)
        while let subNode = current[side]?.node {current = subNode}
        var isDeep = current.deep(dir: side)
        var isOtherDeep = current.deep(dir: side.other)
        current[side] = newNode.mkSubNode(deep: false)
        var child = newNode
        var shift = 0
        while !isDeep && !isOtherDeep {
            child = current
            current[side.other]?.deep = true
            shift += current.advance(dir: side, length: length)
            guard let childInfo = current.getChildInfo() else {return (newNode, shift)}
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
        return (newNode, shift)
    }
    mutating func remove(node: Node) -> NSRange {
        var current: Node
        var dir: Dir
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
}
