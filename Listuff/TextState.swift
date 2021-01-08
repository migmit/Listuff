//
//  TextState.swift
//  Listuff
//
//  Created by MigMit on 27.12.2020.
//

import Combine
import UIKit

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
        let checkmark: UIImage?
        let textIndent: CGFloat
        let firstLineIndent: CGFloat
        let accessory: Accessory?
    }
    struct ListItemInfoIterator: Sequence, IteratorProtocol {
        var lineIterator: Partition<Doc.Line>.Iterator
        let textState: TextState
        init(textState: TextState, charRange: NSRange) {
            self.textState = textState
            self.lineIterator = textState.chunks.covering(from: charRange.location, to: charRange.location + charRange.length)
        }
        mutating func next() -> ListItemInfo? {
            return lineIterator.next().map{textState.lineInfo(range: $0.0, line: $0.1)}
        }
    }
    enum Accessory {
        case bullet(value: String, indent: CGFloat, height: CGFloat, font: UIFont)
        case number(value: String, indent: CGFloat, width: CGFloat, font: UIFont)
    }
    let systemFont = UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
//    let systemFont = UIFont(name: "Arial", size: UIFont.labelFontSize)!
//    let systemFont = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .regular)
//    let systemFont = UIFont(name: "Apple Color Emoji", size: UIFont.labelFontSize)! // <-- what should be instead of .AppleColorEmojiUI (name) or .Apple Color Emoji UI (family)
//    let systemFont = UIFont(name: ".AppleSystemUIFontMonospaced", size: UIFont.labelFontSize)!
//    let systemFont = UIFont(name: "TimesNewRomanPSMT", size: UIFont.labelFontSize)!
    let systemColor = UIColor.label
    let indentationStep = CGFloat(35.0)
    let numIndentStep = CGFloat(25.0)
    let paragraphSpacing = 7.0
    let checked = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .medium))!.withTintColor(UIColor.systemGreen)
    let unchecked = UIImage(systemName: "circle", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .medium))!.withTintColor(UIColor.systemGray2)
    let checkmarkPadding = CGFloat(5.0)
    let checkmarkSize: CGSize
    let bullet = "◦"
    let dash = "-"
    let bulletPadding = CGFloat(5.0)
    let bulletFont = UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
    let bulletWidth: CGFloat
    let numListPadding = CGFloat(5.0)

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
                text: self.chunks.insert(value: $0, length: text.utf16.count, dir: $1, near: $2?.text).0,
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
        self.checkmarkSize = CGSize(width: max(checked.size.width, unchecked.size.width), height: max(checked.size.height, unchecked.size.height))
        let bulletFont = self.bulletFont // to avoid capturing self by closure
        self.bulletWidth = [bullet, dash].map{($0 as NSString).size(withAttributes: [.font: bulletFont]).width}.max()!

        self.text = ""
        self.chunks = Partition()
        self.lines = Partition()
        self.indentVersion = 0
        self.structure = Document.List(listData: DocData.List(version: indentVersion, indent: 0))
        self.numWidthCache = Partition()
        var lastInserted: NodeAppendingState? = nil
        nodes.forEach {lastInserted = appendNode(list: self.structure, after: lastInserted, node: $0)}
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
    func lineInfo(range: NSRange, line: Doc.Line) -> ListItemInfo {
        let hasBullet: Bool
        switch line.parent {
        case .numbered(value: _): hasBullet = false
        case .regular(value: let value): hasBullet = value.value?.style != nil
        }
        let bulletAddition: CGFloat = hasBullet ? bulletWidth + bulletPadding : 0
        //let (paragraphIndent, indexIndent) = calculateIndent(line: line)
        let paragraphIndent: CGFloat
        let indexIndent: CGFloat
        let accessory: Accessory?
        switch line.parent {
        case .numbered(value: let value):
            let item = value.value!
            let width = calcNumWidth(num: item.parent.items.totalLength())
            let index = item.this!.position() + 1
            paragraphIndent = calculateIndent(list: value.value!.parent.parent!)
            indexIndent = calculateIndentStep(nlist: value.value!.parent) + numListPadding
            accessory = .number(value: "\(index).", indent: paragraphIndent, width: width, font: systemFont)
        case .regular(value: let value):
            let bulletString: String?
            switch value.value!.style {
            case .bullet: bulletString = bullet
            case .dash: bulletString = dash
            case nil: bulletString = nil
            }
            paragraphIndent = calculateIndent(list: value.value!.parent!)
            indexIndent = 0
            accessory = bulletString.map{.bullet(value: $0, indent: paragraphIndent, height: ($0 as NSString).size(withAttributes: [.font: bulletFont]).height, font: bulletFont)}
        }
        let checkedAddition = line.checked != nil ? checkmarkSize.width + checkmarkPadding : 0
        let textIndent = paragraphIndent + indexIndent + bulletAddition
        let info = ListItemInfo(
            range: range,
            checkmark: line.checked.map{$0.value ? checked : unchecked},
            textIndent: textIndent,
            firstLineIndent: textIndent + checkedAddition,
            accessory: accessory
        )
        return info
    }
    func lineInfos(charRange: NSRange) -> ListItemInfoIterator {
        return ListItemInfoIterator(textState: self, charRange: charRange)
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
                    indentStack.append((current, numIndentStep + calculateIndentStep(nlist: value.value!.parent)))
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
