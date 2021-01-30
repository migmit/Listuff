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
    typealias Chunk = Partition<Doc.Line, ()>.Node
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
        let parIndent: CGFloat
        let prevParIndent: CGFloat
        let nextParIndent: CGFloat
        let accessory: Accessory?
        let getCorrectFont: (Int) -> (UIFont, NSRange)
        func indentFold(textWidth: CGFloat) -> IndentFold {
            let indentFoldCount = (parIndent * 2 / textWidth).rounded(.down)
            let indentFoldCountInt = Int(indentFoldCount)
            let prevFoldCount = Int((prevParIndent * 2 / textWidth).rounded(.down))
            let nextFoldCount = Int((nextParIndent * 2 / textWidth).rounded(.down))
            return IndentFold (
                foldBack: indentFoldCount * textWidth / 2,
                moreThanPrev: indentFoldCountInt - prevFoldCount,
                moreThanNext: indentFoldCountInt - nextFoldCount
            )
        }
    }
    struct LinkInfo {
        let linkRange: NSRange?
        let color: UIColor
        let isLink: Bool
        let guid: UUID?
    }
    struct ListItemInfoIterator: Sequence, IteratorProtocol {
        var lineIterator: Partition<Doc.Line, ()>.Iterator
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
    class FontCache {
        lazy var systemFont: UIFont = UIFont.preferredFont(forTextStyle: .body)
        lazy var titleFont: UIFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        lazy var chapterFont: UIFont = UIFont.preferredFont(forTextStyle: .title1)
        lazy var sectionFont: UIFont = UIFont.preferredFont(forTextStyle: .title2)
        lazy var subsectionFont: UIFont = UIFont.preferredFont(forTextStyle: .title3)
        let bullet = "◦"
        let dash = "-"
        lazy var bulletFont: UIFont =
            UIFont.monospacedSystemFont(ofSize: systemFont.pointSize, weight: .regular)
        lazy var bulletWidth: CGFloat = [bullet, dash].map{$0.size(font: bulletFont).width}.max()!
        lazy var checked: UIImage =
            UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .medium))!.withTintColor(UIColor.systemGreen)
        lazy var unchecked: UIImage =
            UIImage(systemName: "circle", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .medium))!.withTintColor(UIColor.systemGray2)
        lazy var checkmarkSize: CGSize =
            CGSize(
                width: max(checked.size.width, unchecked.size.width),
                height: max(checked.size.height, unchecked.size.height)
            )
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
    let systemColor = UIColor.label
    let liveLinkColor = UIColor.link
    let brokenLinkColor = UIColor.red
    let indentationStep = CGFloat(35.0)
    let numIndentStep = CGFloat(25.0)
    let paragraphSpacing = 7.0
    let checkmarkPadding = CGFloat(5.0)
    let bulletPadding = CGFloat(10.0)
    let numListPadding = CGFloat(5.0)

    var text: String
    var chunks: Partition<Doc.Line, ()>
    var structure: Doc.Document
    var fontCache: FontCache
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
    
    init(title: String, checked: Bool? = nil, linkId: String? = nil, links: [(Range<Int>, String)] = [], appendables: [Appendable]) {
        self.fontCache = FontCache()
        self.renderingCache = RenderingCache(version: 0)
        var fulltext = ""
        var chunks = Partition<Doc.Line, ()>(parent: ())
        let linkAppender = LinkAppender()
        let appender = NodeAppender(title: title, checked: checked, linkId: linkId, links: links) {text, linkId, links, line in
            let nsLinks: [(NSRange, String)] = links.map {
                let (range, lid) = $0
                return (NSRange(range, in: text), lid)
            }
            linkAppender.appendLine(shift: fulltext.utf16.count, linkId: linkId, nsLinks: nsLinks, line: line)
            fulltext += text
            return DocData.Text(text: chunks.insert(value: line, length: text.utf16.count, dir: .Left, near: nil).0, guid: nil, backlinks: [])
        }
        appendables.forEach{$0.append(to: appender)}
        self.text = fulltext
        self.chunks = chunks
        self.structure = appender.document
        linkAppender.processLinks(fullSize: self.text.utf16.count, linkStructure: self.linkStructure)
    }
    var checkmarkSize: CGSize {fontCache.checkmarkSize}
    func invalidate() {
        fontCache = FontCache()
        renderingCache.invalidate()
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
        let bulletAddition: CGFloat = hasBullet ? fontCache.bulletWidth + bulletPadding : 0
        let paragraphIndent: CGFloat = calculateParIndent(line: line)
        let indexIndent: CGFloat
        let accessory: Accessory?
        switch line.parent {
        case .numbered(value: let value):
            let item = value.value!
            let width = calculateIndentStep(nlist: item.this!.partitionParent.value!)
            let index = item.this!.range.location + 1
            indexIndent = width + numListPadding
            accessory = .number(value: "\(index).", indent: paragraphIndent, width: width, font: fontCache.systemFont)
        case .regular(value: let value):
            let bulletString: String?
            switch value.value!.style {
            case .bullet: bulletString = fontCache.bullet
            case .dash: bulletString = fontCache.dash
            case nil: bulletString = nil
            }
            indexIndent = 0
            accessory = bulletString.map{.bullet(value: $0, indent: paragraphIndent, height: $0.size(font: fontCache.bulletFont).height, font: fontCache.bulletFont)}
        default:
            indexIndent = 0
            accessory = nil
        }
        let checkedAddition = line.checked != nil ? fontCache.checkmarkSize.width + checkmarkPadding : 0
        let textIndent = paragraphIndent + indexIndent + bulletAddition
        let lineText = text[range]
        let info = ListItemInfo(
            range: range,
            checkmark: line.checked.map{$0.value ? fontCache.checked : fontCache.unchecked},
            textIndent: textIndent,
            firstLineIndent: textIndent + checkedAddition,
            parIndent: paragraphIndent,
            prevParIndent: (line.content?.text?.near(dir: .Left)?.value).map(calculateParIndent) ?? 0,
            nextParIndent: (line.content?.text?.near(dir: .Right)?.value).map(calculateParIndent) ?? 0,
            accessory: accessory,
            getCorrectFont: {(pos) in self.getCorrectFont(line: line, text: lineText, pos: pos)}
        )
        return info
    }
    func lineInfos(charRange: NSRange) -> ListItemInfoIterator {
        return ListItemInfoIterator(textState: self, charRange: charRange)
    }
    func linkInfo(pos: Int) -> LinkInfo {
        let liveInfo = linkStructure.livingLinks.search(pos: pos)
        let brokenInfo = linkStructure.brokenLinks.search(pos: pos)
        let liveLink: Bool?
        let guid: UUID?
        if let (_, guidOpt) = liveInfo, let g = guidOpt {
            liveLink = true
            guid = g
        } else if let (_, guidOpt) = brokenInfo, let g = guidOpt {
            liveLink = false
            guid = g
        } else {
            liveLink = nil
            guid = nil
        }
        let linkRange: NSRange?
        if let (lr, _) = liveInfo {
            if let (br, _) = brokenInfo {
                linkRange = NSIntersectionRange(lr, br)
            } else {
                linkRange = lr
            }
        } else {
            linkRange = brokenInfo?.0
        }
        let color: UIColor
        if let ll = liveLink {
            color = ll ? liveLinkColor : brokenLinkColor
        } else {
            color = systemColor
        }
        return LinkInfo(linkRange: linkRange, color: color, isLink: liveLink != nil, guid: guid)
    }
    func calculateIndentStep(nlist: Doc.NumberedList) -> CGFloat {
        if let listData = nlist.listData, listData.version == renderingCache.version {
            return listData.indentStep
        }
        let indentStep = renderingCache.numWidth(num: nlist.count, font: fontCache.systemFont)
        nlist.listData = DocData.NumberedList(version: renderingCache.version, indentStep: indentStep)
        return indentStep
    }
    struct IndentStack {
        let textState: TextState
        var stack: [(Doc.List, CGFloat)]
        mutating func append(current: Doc.List) -> Doc.List? {
            switch current.parent {
            case .regular(value: let value):
                stack.append((current, textState.indentationStep))
                return value.value!.this!.partitionParent.value!
            case .numbered(value: let value):
                let parent = value.value!.this!.partitionParent.value!
                stack.append((current, textState.numIndentStep + textState.calculateIndentStep(nlist: parent)))
                return parent.this!.partitionParent.value!
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
            list.listData = DocData.List(version: renderingCache.version, indent: result)
        }
        return result
    }
    func calculateParIndent(line: Doc.Line) -> CGFloat {
        switch line.parent {
        case .numbered(value: let value):
            return calculateIndent(list: value.value!.this!.partitionParent.value!.this!.partitionParent.value!)
        case .regular(value: let value):
            return calculateIndent(list: value.value!.this!.partitionParent.value!)
        default:
            return 0
        }
    }
    func getCorrectFont(line: Doc.Line, text: String, pos: Int) -> (UIFont, NSRange) {
        var range: NSRange = NSRange.item(at: pos)
        if let cache = line.lineData, cache.version == renderingCache.version {
            let font = cache.rendered.attribute(.font, at: pos, effectiveRange: &range) as? UIFont
            return (font ?? fontCache.systemFont, range)
        }
        let baseFont: UIFont
        switch line.parent {
        case .document(value: _): baseFont = fontCache.titleFont
        case .chapter(value: _): baseFont = fontCache.chapterFont
        case .section(value: _): baseFont = fontCache.sectionFont
        case .subsection(value: _): baseFont = fontCache.subsectionFont
        default: baseFont = fontCache.systemFont
        }
        let rendered = NSMutableAttributedString(string: text, attributes: [.font: baseFont])
        rendered.fixAttributes(in: rendered.fullRange)
        line.lineData = DocData.Line(version: renderingCache.version, rendered: rendered)
        let font = rendered.attribute(.font, at: pos, effectiveRange: &range) as? UIFont
        return (font ?? baseFont, range)
    }
}
