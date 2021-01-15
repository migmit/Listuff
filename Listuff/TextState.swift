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
    typealias Doc = Structure<DocData>
    typealias Chunk = Partition<Doc.Line>.Node
    typealias EventPublisher = AnyPublisher<Event, Never>
    enum Event {
        case Insert(node: Chunk, range: NSRange)
        case Remove(value: Doc.Line, oldRange: NSRange)
        case SetLength(value: Doc.Line, length: Int, oldRange: NSRange)
    }
    struct IndentFold {
        let foldBack: CGFloat
        let moreThanPrev: Int
        let moreThanNext: Int
    }
    struct ListItemInfo {
        let range: NSRange
        let checkmark: UIImage?
        let textIndent: CGFloat
        let firstLineIndent: CGFloat
        let prevTextIndent: CGFloat
        let nextTextIndent: CGFloat
        let accessory: Accessory?
        let getCorrectFont: (Int) -> (UIFont, NSRange)
        func indentFold(textWidth: CGFloat) -> IndentFold {
            let indentFoldCount = (textIndent * 2 / textWidth).rounded(.down)
            let indentFoldCountInt = Int(indentFoldCount)
            let prevFoldCount = Int((prevTextIndent * 2 / textWidth).rounded(.down))
            let nextFoldCount = Int((nextTextIndent * 2 / textWidth).rounded(.down))
            return IndentFold (
                foldBack: indentFoldCount * textWidth / 2,
                moreThanPrev: indentFoldCountInt - prevFoldCount,
                moreThanNext: indentFoldCountInt - nextFoldCount
            )
        }
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
    struct RenderingCache {
        var version: Int
        var numWidths: [CGFloat]
        init(version: Int) {
            self.version = version
            self.numWidths = []
        }
        mutating func numWidth(num: Int, font: UIFont) -> CGFloat {
            if num <= numWidths.count {
                return numWidths[num-1]
            } else {
                var maxWidth = numWidths.last ?? 0
                for n in numWidths.count ..< num {
                    maxWidth = max("\(n+1).".size(font: font).width, maxWidth)
                    numWidths.append(maxWidth)
                }
                return maxWidth
            }
        }
        mutating func invalidate() {
            numWidths = []
            version += 1
        }
    }
//    let systemFont = UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
//    let systemFont = UIFont(name: "Arial", size: UIFont.labelFontSize)!
//    let systemFont = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .regular)
//    let systemFont = UIFont(name: "Apple Color Emoji", size: UIFont.labelFontSize)! // <-- what should be instead of .AppleColorEmojiUI (name) or .Apple Color Emoji UI (family)
//    let systemFont = UIFont(name: ".AppleSystemUIFontMonospaced", size: UIFont.labelFontSize)!
//    let systemFont = UIFont(name: "TimesNewRomanPSMT", size: UIFont.labelFontSize)!
    let systemFont = UIFont.preferredFont(forTextStyle: .body)
    let chapterFont = UIFont.preferredFont(forTextStyle: .title1)
    let sectionFont = UIFont.preferredFont(forTextStyle: .title2)
    let subsectionFont = UIFont.preferredFont(forTextStyle: .title3)
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
    let bulletPadding = CGFloat(10.0)
    let bulletFont = UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
    let bulletWidth: CGFloat
    let numListPadding = CGFloat(5.0)

    var text: String
    var chunks: Partition<Doc.Line>
    var structure: Doc.Document
    var renderingCache: RenderingCache
    var items: [Substring] {
        var result: [Substring] = []
        for (bounds, _) in chunks {
            if let r = Range(bounds, in: text) {
                result.append(text[r])
            }
        }
        return result
    }
    
    let linkStructure = LinkStructure()
    
    private let eventsPublisher = PassthroughSubject<Event, Never>()
    var events: EventPublisher {
        return eventsPublisher.eraseToAnyPublisher()
    }
    
    init(appendables: [Appendable]) {
        self.checkmarkSize = CGSize(width: max(checked.size.width, unchecked.size.width), height: max(checked.size.height, unchecked.size.height))
        let bulletFont = self.bulletFont // to avoid capturing self by closure
        self.bulletWidth = [bullet, dash].map{$0.size(font: bulletFont).width}.max()!
//        self.chapterFont = UIFont(descriptor: systemFont.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 20.0)
//        self.sectionFont = UIFont(descriptor: systemFont.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 18.0)
//        self.subsectionFont = UIFont(descriptor: systemFont.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 16.0)

        self.renderingCache = RenderingCache(version: 0)
        self.text = ""
        self.chunks = Partition()
        self.structure = Structure.Document()
        let linkAppender = LinkAppender()
        let appender = NodeAppender {text, linkId, links, after, line in
            let nsLinks: [(NSRange, String)] = links.map {
                let (range, lid) = $0
                return (NSRange(range, in: text), lid)
            }
            linkAppender.appendLine(shift: self.text.utf16.count, linkId: linkId, nsLinks: nsLinks, line: line)
            self.text += text
            return DocData.Line(text: self.chunks.insert(value: line, length: text.utf16.count, dir: .Right, near: after?.content?.text).0, cache: nil, guid: nil, backlinks: [])
        }
        appendables.forEach{$0.append(to: appender)}
        self.structure = appender.document
        linkAppender.processLinks(fullSize: self.text.utf16.count, linkStructure: self.linkStructure)
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
        case .regular(value: let value): hasBullet = value.value?.style != nil
        default: hasBullet = false
        }
        let bulletAddition: CGFloat = hasBullet ? bulletWidth + bulletPadding : 0
        let paragraphIndent: CGFloat = calculateParIndent(line: line)
        let indexIndent: CGFloat
        let accessory: Accessory?
        switch line.parent {
        case .numbered(value: let value):
            let item = value.value!
            let width = calculateIndentStep(nlist: item.parent!)
            let index = item.this!.range.location + 1
            indexIndent = width + numListPadding
            accessory = .number(value: "\(index).", indent: paragraphIndent, width: width, font: systemFont)
        case .regular(value: let value):
            let bulletString: String?
            switch value.value!.style {
            case .bullet: bulletString = bullet
            case .dash: bulletString = dash
            case nil: bulletString = nil
            }
            indexIndent = 0
            accessory = bulletString.map{.bullet(value: $0, indent: paragraphIndent, height: $0.size(font: bulletFont).height, font: bulletFont)}
        default:
            indexIndent = 0
            accessory = nil
        }
        let checkedAddition = line.checked != nil ? checkmarkSize.width + checkmarkPadding : 0
        let textIndent = paragraphIndent + indexIndent + bulletAddition
        let lineText = text[range]
        let info = ListItemInfo(
            range: range,
            checkmark: line.checked.map{$0.value ? checked : unchecked},
            textIndent: textIndent,
            firstLineIndent: textIndent + checkedAddition,
            prevTextIndent: (line.content?.text?.near(dir: .Left)?.value).map(calculateParIndent) ?? 0,
            nextTextIndent: (line.content?.text?.near(dir: .Right)?.value).map(calculateParIndent) ?? 0,
            accessory: accessory,
            getCorrectFont: {(pos) in self.getCorrectFont(line: line, text: lineText, pos: pos)}
        )
        return info
    }
    func lineInfos(charRange: NSRange) -> ListItemInfoIterator {
        return ListItemInfoIterator(textState: self, charRange: charRange)
    }
    func calculateIndentStep(nlist: Doc.NumberedList) -> CGFloat {
        if let listData = nlist.listData, listData.version == renderingCache.version {
            return listData.indentStep
        }
        let indentStep = renderingCache.numWidth(num: nlist.items.totalLength(), font: systemFont)
        nlist.listData = DocData.NumberedListImpl(version: renderingCache.version, indentStep: indentStep)
        return indentStep
    }
    struct IndentStack {
        let textState: TextState
        var stack: [(Doc.List, CGFloat)]
        mutating func append(current: Doc.List) -> Doc.List? {
            switch current.parent {
            case .numbered(value: let value):
                let parent = value.value!.parent!
                stack.append((current, textState.numIndentStep + textState.calculateIndentStep(nlist: parent)))
                return parent.parent!
            case .sublist(value: let value):
                stack.append((current, textState.indentationStep))
                return value.value!.parent!
            default:
                return nil
            }
        }
    }
    func calculateIndent(list: Doc.List) -> CGFloat {
        var current: Doc.List? = list
        var indentStack = IndentStack(textState: self, stack: [])
        var result: CGFloat = 0
        while let c = current, c.listData?.version != renderingCache.version {
            current = indentStack.append(current: c)
        }
        if let listData = current?.listData, listData.version == renderingCache.version {
            result = listData.indent
        }
        for (list, indentStep) in indentStack.stack.reversed() {
            result += indentStep
            list.listData = DocData.ListImpl(version: renderingCache.version, indent: result)
        }
        return result
    }
    func calculateParIndent(line: Doc.Line) -> CGFloat {
        switch line.parent {
        case .numbered(value: let value):
            return calculateIndent(list: value.value!.parent!.parent!)
        case .regular(value: let value):
            return calculateIndent(list: value.value!.parent!)
        default:
            return 0
        }
    }
    func getCorrectFont(line: Doc.Line, text: String, pos: Int) -> (UIFont, NSRange) {
        let content = line.content!
        var range: NSRange = NSRange.item(at: pos)
        if let cache = content.cache, cache.version == renderingCache.version {
            let font = cache.rendered.attribute(.font, at: pos, effectiveRange: &range) as? UIFont
            return (font ?? systemFont, range)
        }
        let baseFont: UIFont
        switch line.parent {
        case .chapter(value: _): baseFont = chapterFont
        case .section(value: _): baseFont = sectionFont
        case .subsection(value: _): baseFont = subsectionFont
        default: baseFont = systemFont
        }
        let rendered = NSMutableAttributedString(string: text, attributes: [.font: baseFont])
        rendered.fixAttributes(in: rendered.fullRange)
        line.content?.cache = DocData.LineRenderingImpl(version: renderingCache.version, rendered: rendered)
        let font = rendered.attribute(.font, at: pos, effectiveRange: &range) as? UIFont
        return (font ?? baseFont, range)
    }
}
