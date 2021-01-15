//
//  TextView.swift
//  Listuff
//
//  Created by MigMit on 09.01.2021.
//

import SwiftUI

struct HierarchyView: View {
    let content: TextState
    var body: some View {
        GeometryReader {geometry in
            HierarchyViewImpl(content: content, textWidth: geometry.size.width)
        }
    }
}

struct HierarchyViewImpl: UIViewRepresentable {
    typealias UIViewType = TextView
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
    
    let content: TextState
    let textWidth: CGFloat
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> TextView {
        return TextView(frame: .zero, content: content, textWidth: textWidth, context: context)
    }
    
    func updateUIView(_ uiView: TextView, context: Context) {
        uiView.updateTextWidth(textWidth: textWidth)
    }
    
    class TextView: UITextView, UIGestureRecognizerDelegate {
        let content: TextState
        let storage: TextStorage
        let manager: LayoutManager
        let container: NSTextContainer
        var gesture: UIGestureRecognizer? = nil
        var textWidth: CGFloat
        init(frame: CGRect, content: TextState, textWidth: CGFloat, context: Context) {
            self.content = content
            self.storage = TextStorage(content: content, textWidth: textWidth)
            self.manager = LayoutManager(content: content, textWidth: textWidth)
            self.container = NSTextContainer()
            self.textWidth = textWidth
            self.storage.addLayoutManager(self.manager)
            self.manager.addTextContainer(self.container)
            super.init(frame: frame, textContainer: container)
            let gesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
            self.gesture = gesture
            gesture.delegate = context.coordinator
            self.addGestureRecognizer(gesture)
        }
        
        required init?(coder: NSCoder) {
            return nil
        }
        
        func updateTextWidth(textWidth: CGFloat) {
            self.textWidth = textWidth
            storage.updateTextWidth(textWidth: textWidth)
            manager.updateTextWidth(textWidth: textWidth)
        }
        
        @objc func tapped(gestureRecognizer: UIGestureRecognizer) {
            let location = gestureRecognizer.location(in: self)
            let realLocation = location.shift(by: CGVector(dx: -textContainerInset.left, dy: -textContainerInset.top))
            let idx = layoutManager.characterIndex(for: realLocation, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
            if let (range, line) = content.chunks.search(pos: idx), let checked = line.checked {
                let lineInfo = content.lineInfo(range: range, line: line)
                let indentFold = lineInfo.indentFold(textWidth: textWidth)
                let glRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if glRange.length <= 0 {return}
                let correctedGlyphRange = glRange.firstItem
                layoutManager.enumerateLineFragments(forGlyphRange: correctedGlyphRange) {_, usedRect, textContainer, _, ptrStop in
                    let fragmentPadding = textContainer.lineFragmentPadding
                    let imageOrigin = CGPoint(
                        x: lineInfo.textIndent + fragmentPadding,
                        y: usedRect.midY - self.content.checkmarkSize.height / 2
                    )
                    let imageRect = CGRect(origin: imageOrigin, size: self.content.checkmarkSize)
                    if imageRect.contains(realLocation.shift(by: CGVector(dx: indentFold.foldBack, dy: 0))) {
                        line.checked = TextState.Doc.Checked(value: !checked.value)
                        self.layoutManager.invalidateDisplay(forGlyphRange: correctedGlyphRange)
                        self.selectedRange = NSRange.empty(at: self.content.text.getLineEnd(pos: range.location))
                    }
                    ptrStop[0] = true
                }
            }
        }
        
        override func copy(_ sender: Any?) {
            print("Copy")
            super.copy(sender)
        }
        override func cut(_ sender: Any?) {
            print("Cut")
            super.cut(sender)
        }
        override func paste(_ sender: Any?) {
            print("Paste")
            debugPaste()
            super.paste(sender)
        }
    }
    
    class TextStorage: NSTextStorage {
        let content: TextState
        var textWidth: CGFloat
        init(content: TextState, textWidth: CGFloat) {
            self.content = content
            self.textWidth = textWidth
            super.init()
        }
        required init?(coder: NSCoder) {
            return nil
        }
        override var string: String {
            return content.text
        }
        func updateTextWidth(textWidth: CGFloat) {
            self.textWidth = textWidth
        }
        override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
            let limitingRange: NSRange?
            let liveLink: Bool?
            let liveInfo = content.linkStructure.livingLinks.search(pos: location)
            let brokenInfo = content.linkStructure.brokenLinks.search(pos: location)
            if let (lr, _) = liveInfo {
                if let (br, _) = brokenInfo {
                    limitingRange = NSIntersectionRange(lr, br)
                } else {
                    limitingRange = lr
                }
            } else {
                limitingRange = brokenInfo?.0
            }
            if let (_, guidOpt) = liveInfo, guidOpt != nil {
                liveLink = true
            } else if let (_, guidOpt) = brokenInfo, guidOpt != nil {
                liveLink = false
            } else {
                liveLink = nil
            }
            for lineInfo in content.lineInfos(charRange: NSRange.item(at: location)) {
                let (font, fontRange) = lineInfo.getCorrectFont(location - lineInfo.range.location)
                if let rangePtr = range {
                    let realFontRange = fontRange.shift(by: lineInfo.range.location)
                    if let lRange = limitingRange {
                        rangePtr[0] = NSIntersectionRange(realFontRange, lRange)
                    } else {
                        rangePtr[0] = realFontRange
                    }
                }
                let paragraphStyle = NSMutableParagraphStyle()
                if lineInfo.checkmark != nil {
                    paragraphStyle.minimumLineHeight = content.checkmarkSize.height
                }
                let indentFold = lineInfo.indentFold(textWidth: textWidth)
                paragraphStyle.headIndent = lineInfo.textIndent - indentFold.foldBack
                paragraphStyle.firstLineHeadIndent = lineInfo.firstLineIndent - indentFold.foldBack
                paragraphStyle.paragraphSpacing = CGFloat(content.paragraphSpacing)
                let color: UIColor
                if let ll = liveLink {
                    color = ll ? UIColor.blue : UIColor.red
                } else {
                    color = content.systemColor
                }
                return [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle,
                    .underlineStyle: liveLink != nil ? NSUnderlineStyle.single.rawValue : 0
                ]
            }
            NSException(name: .rangeException, reason: "Position \(location) out of bounds", userInfo: [:]).raise()
            return [:] // Never happens
        }
        override func replaceCharacters(in range: NSRange, with str: String) {
            let (changedRange, changeInLength) = content.replaceCharacters(in: range, with: str)
            edited(.editedCharacters, range: changedRange, changeInLength: changeInLength)
        }
        override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
            // TOFIX
            edited(.editedAttributes, range: range, changeInLength: 0)
        }
    }
    class LayoutManager: NSLayoutManager {
        let content: TextState
        var textWidth: CGFloat
        init(content: TextState, textWidth: CGFloat) {
            self.content = content
            self.textWidth = textWidth
            super.init()
            self.allowsNonContiguousLayout = true
        }
        required init?(coder: NSCoder) {
            return nil
        }
        func updateTextWidth(textWidth: CGFloat) {
            self.textWidth = textWidth
        }
        func drawAccessory(accessory: TextState.Accessory, origin: CGPoint, boxYPos: CGFloat, boxHeight: CGFloat, fragmentPadding: CGFloat) {
            switch accessory {
            case .bullet(value: let value, indent: let indent, height: let height, font: let font):
                value.draw(at: origin.shift(by: CGVector(dx: indent + fragmentPadding, dy: boxYPos + (boxHeight - height) / 2)), withAttributes: [.font: font])
            case .number(value: let value, indent: let indent, width: let width, font: let font):
                let parStyle = NSMutableParagraphStyle()
                parStyle.alignment = .right
                let numRect = CGRect(x: indent + fragmentPadding + origin.x, y: boxYPos + origin.y, width: width, height: boxHeight)
                value.draw(in: numRect, withAttributes: [.font: font, .paragraphStyle: parStyle])
            }
        }
        func drawDivider(minX: CGFloat, maxX: CGFloat, y: CGFloat, linecapDir: CGFloat, dashed: Bool, color: UIColor) {
            let linecap = CGFloat(4.0)
            let dashedLine = UIBezierPath()
            dashedLine.move(to: CGPoint(x: minX + linecap, y: y))
            dashedLine.addLine(to: CGPoint(x: maxX, y: y))
            if (dashed) {
                var dashes = [CGFloat(8.0), CGFloat(8.0)]
                dashedLine.setLineDash(&dashes, count: dashes.count, phase: 0.0)
            }
            dashedLine.lineWidth = 1.0
            dashedLine.lineCapStyle = .butt
            let line = UIBezierPath()
            line.move(to: CGPoint(x: minX + linecap, y: y))
            line.addLine(to: CGPoint(x: minX, y: y + linecap * linecapDir))
            color.set()
            dashedLine.stroke()
            line.stroke()
        }
        override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            for lineInfo in content.lineInfos(charRange: characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)) {
                let glRange = glyphRange(forCharacterRange: lineInfo.range, actualCharacterRange: nil)
                if glRange.length <= 0 {continue}
                let indentFold = lineInfo.indentFold(textWidth: self.textWidth)
                enumerateLineFragments(forGlyphRange: glRange.firstItem) {rect, usedRect, textContainer, _, ptrStop in
                    ptrStop[0] = true
                    let fragmentPadding = textContainer.lineFragmentPadding - indentFold.foldBack
                    if let accessory = lineInfo.accessory {
                        self.drawAccessory(accessory: accessory, origin: origin, boxYPos: usedRect.origin.y, boxHeight: usedRect.size.height, fragmentPadding: fragmentPadding)
                    }
                    if let checkmark = lineInfo.checkmark {
                        let imageOrigin = origin.shift(by: CGVector(
                            dx: lineInfo.textIndent + fragmentPadding,
                            dy: usedRect.midY - checkmark.size.height / 2
                        ))
                        checkmark.draw(at: imageOrigin)
                    }
                    if (indentFold.moreThanPrev > 0) {
                        self.drawDivider(
                            minX: rect.minX + origin.x,
                            maxX: rect.maxX + origin.x,
                            y: origin.y + usedRect.midY - rect.height / 2,
                            linecapDir: 1.0,
                            dashed: indentFold.moreThanPrev == 1,
                            color: UIColor.systemBlue
                        )
                    }
//                    let gc = UIGraphicsGetCurrentContext()!
//                    UIColor.green.set()
//                    gc.addRect(CGRect(origin: CGPoint(x: usedRect.minX + origin.x, y: usedRect.minY + origin.y), size: usedRect.size))
//                    gc.strokePath()
                }
                if (indentFold.moreThanNext > 0) {
                    enumerateLineFragments(forGlyphRange: NSRange.item(at: glRange.end - 1)) {rect, usedRect, _, _, ptrStop in
                        ptrStop[0] = true
                        self.drawDivider(
                            minX: rect.minX + origin.x,
                            maxX: rect.maxX + origin.x,
                            y: origin.y + usedRect.midY + rect.height / 2,
                            linecapDir: -1.0,
                            dashed: indentFold.moreThanNext == 1,
                            color: UIColor.systemPurple
                        )
                    }
                }
            }
        }
    }
}
