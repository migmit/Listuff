//
//  WAVL.swift
//  Listuff
//
//  Created by MigMit on 29.11.2020.
//

import Foundation

struct WAVLTree<V> {
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
        func advance(dir: Dir, length: Int) {
            if case .Left = dir {
                end += length
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
    func search(pos: Int) -> (NSRange, V)? {
        return searchNode(pos: pos).map {($0.0, $0.1.value)}
    }
    private func leftmostChild(node: Node) -> Node {
        var current = node
        while let child = current[.Left]?.node {current = child}
        return current
    }
    func foldLeft<T>(_ initial: T, op: (T, V) -> T) -> T {
        return foldLeftBounds(initial) {op($0, $2)}
    }
    func foldLeftBounds<T>(_ initial: T, from: Int = 0, to: Int? = nil, op: (T, NSRange, V) -> T) -> T {
        guard let (startBounds, startNode) = searchNode(pos: from) else {return initial}
        var result = initial
        var currentNode = startNode
        var currentLeft = startBounds.location
        var currentLength = startBounds.length
        var cameFromLeft = true
        while cameFromLeft && (to.map {$0 > currentLeft} ?? true) {
            result = op(result, NSMakeRange(currentLeft, currentLength), currentNode.value)
            currentLeft += currentLength
            if let child = currentNode[.Right]?.node {
                currentNode = leftmostChild(node: child)
                currentLength = currentNode.end
            } else {
                currentLength = 0
                cameFromLeft = false
                while !cameFromLeft, let (parent, dir, _) = currentNode.getChildInfo() {
                    currentLength -= currentNode.end
                    currentNode = parent
                    cameFromLeft = dir == .Left
                }
                currentLength += currentNode.end
            }
        }
        return result
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
    func advanceRecurse(node: Node, length: Int) {
        var current = node
        while let (parent, dir, _) = current.getChildInfo() {
            parent.advance(dir: dir, length: length)
            current = parent
        }
    }
    mutating func insert(value: V, length: Int, dir: Dir = .Right, near: Node? = nil) -> Node {
        let newNode = Node(value: value, length: length)
        guard let r = root else {
            root = newNode
            return newNode
        }
        var (current, side) = near.map {n in (n[dir]?.node).map{($0, dir.other)} ?? (n, dir)} ?? (r, dir.other)
        while let subNode = current[side]?.node {current = subNode}
        var isDeep = current.deep(dir: side)
        var isOtherDeep = current.deep(dir: side.other)
        current[side] = newNode.mkSubNode(deep: false)
        var child = newNode
        while !isDeep && !isOtherDeep {
            child = current
            current[side.other]?.deep = true
            current.advance(dir: side, length: length)
            guard let childInfo = current.getChildInfo() else {return newNode}
            (current, side, isDeep) = childInfo
            isOtherDeep = current.deep(dir: side.other)
        }
        if (isDeep) {
            current[side]?.deep = false
            current.advance(dir: side, length: length)
            advanceRecurse(node: current, length: length)
        } else {
            if (child.deep(dir: side)) {
                let grandchild = child[side.other]!.node // if child[side.other] = nil, then child is a leaf (then child.deep(_) = false) or child[side] is a leaf (then child.deep(side) = false)
                replace(node: current, with: grandchild)
                grandchild.advance(dir: side, length: child.end)
                current.advance(dir: side, length: length - grandchild.end)
                child.advance(dir: side.other, length: -grandchild.end)
                grandchild.advance(dir: side.other, length: current.end)
                child[side]?.deep = false
                child[side.other] = grandchild[side]
                current[side] = grandchild[side.other]
                current[side.other]?.deep = false
                grandchild[side] = child.mkSubNode(deep: false)
                grandchild[side.other] = current.mkSubNode(deep: false)
                advanceRecurse(node: grandchild, length: length)
            } else {
                replace(node: current, with: child)
                current.advance(dir: side, length: length - child.end)
                child.advance(dir: side.other, length: current.end)
                current[side] = child[side.other]?.node.mkSubNode(deep: false)
                current[side.other]?.deep = false
                child[side.other] = current.mkSubNode(deep: false)
                advanceRecurse(node: child, length: length)
            }
        }
        return newNode
    }
    mutating func remove(node: Node) {
        var current: Node
        var dir: Dir
        var isDeep: Bool
        var length = node.end
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
            target[.Right] = node[.Right]
            target.copyEnd(other: node)
            replace(node: node, with: target)
        } else {
            guard let childInfo = node.getChildInfo() else {
                if root === node {
                    root = node[.Right]?.node
                    root?.detach()
                }
                return
            }
            (current, dir, isDeep) = childInfo
            current[dir] = node[.Right]?.node.mkSubNode(deep: isDeep)
        }
        if !isDeep && current[dir] == nil && current[dir.other] == nil {
            current.advance(dir: dir, length: -length)
            guard let childInfo = current.getChildInfo() else {return}
            (current, dir, isDeep) = childInfo
        }
        while isDeep {
            if current.deep(dir: dir.other) {
                current.advance(dir: dir, length: -length)
                current[dir.other]?.deep = false
                guard let childInfo = current.getChildInfo() else {return}
                (current, dir, isDeep) = childInfo
            } else {
                let child = current[dir.other]!.node
                if child.deep(dir: dir.other) {
                    if child.deep(dir: dir) {
                        current.advance(dir: dir, length: -length)
                        child[dir]?.deep = false
                        child[dir.other]?.deep = false
                        guard let childInfo = current.getChildInfo() else {return}
                        (current, dir, isDeep) = childInfo
                    } else {
                        let grandchild = child[dir]!.node
                        replace(node: current, with: grandchild)
                        current.advance(dir: dir, length: -length)
                        child.advance(dir: dir, length: -grandchild.end)
                        grandchild.advance(dir: dir, length: current.end)
                        grandchild.advance(dir: dir.other, length: child.end)
                        current.advance(dir: dir.other, length: -grandchild.end)
                        current[dir]?.deep = false
                        current[dir.other] = grandchild[dir]
                        child[dir] = grandchild[dir.other]
                        child[dir.other]?.deep = false
                        grandchild[dir] = current.mkSubNode(deep: true)
                        grandchild[dir.other] = child.mkSubNode(deep: true)
                        advanceRecurse(node: grandchild, length: -length)
                        return
                    }
                } else {
                    replace(node: current, with: child)
                    current.advance(dir: dir, length: -length)
                    child.advance(dir: dir, length: current.end)
                    current.advance(dir: dir.other, length: -child.end)
                    current[dir.other] = child[dir]
                    child[dir.other]?.deep = true
                    child[dir] = current.mkSubNode(deep: current[.Left] == nil && current[.Right] == nil)
                    advanceRecurse(node: child, length: -length)
                    return
                }
            }
        }
        current[dir]?.deep = true
        current.advance(dir: dir, length: -length)
        advanceRecurse(node: current, length: -length)
    }
}
