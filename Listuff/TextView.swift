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
            HierarchyViewImpl(content: content, textSize: geometry.size)
        }
    }
}

struct HierarchyViewImpl: UIViewRepresentable {
    typealias UIViewType = TextView
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var textView: TextView? = nil
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            textView?.saveSelectedRange()
            return true
        }
    }
    
    let content: TextState
    let textSize: CGSize
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> TextView {
        let textView = TextView(frame: .zero, content: content, textSize: textSize, context: context)
        context.coordinator.textView = textView
        return textView
    }
    
    func updateUIView(_ uiView: TextView, context: Context) {
        uiView.updateTextSize(textSize: textSize)
    }
    
    class TextView: UITextView, UIGestureRecognizerDelegate {
        let content: TextState
        let storage: TextStorage
        let manager: LayoutManager
        let container: NSTextContainer
        var gesture: UIGestureRecognizer? = nil
        var textSize: CGSize
        var savedSelectedRange: NSRange
        init(frame: CGRect, content: TextState, textSize: CGSize, context: Context) {
            self.content = content
            self.storage = TextStorage(content: content, textWidth: textSize.width)
            self.manager = LayoutManager(content: content, textWidth: textSize.width)
            self.container = NSTextContainer()
            self.textSize = textSize
            self.storage.addLayoutManager(self.manager)
            self.manager.addTextContainer(self.container)
            self.savedSelectedRange = NSRange.empty(at: 0)
            super.init(frame: frame, textContainer: container)
            let gesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
            self.gesture = gesture
            gesture.delegate = context.coordinator
            self.addGestureRecognizer(gesture)
        }
        
        required init?(coder: NSCoder) {
            return nil
        }
        
        func saveSelectedRange() {
            savedSelectedRange = selectedRange
        }
        
        func updateTextSize(textSize: CGSize) {
            self.textSize = textSize
            storage.updateTextWidth(textWidth: textSize.width)
            manager.updateTextWidth(textWidth: textSize.width)
        }
        
        func scrollToRange(range: NSRange) {
            let boundingBox = manager.boundingRect(forGlyphRange: manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
            let scrollPos: CGFloat
            if boundingBox.height > textSize.height {
                scrollPos = boundingBox.minY
            } else if boundingBox.height > textSize.height / 2 {
                scrollPos = boundingBox.maxY - textSize.height
            } else {
                scrollPos = boundingBox.minY - textSize.height / 2
            }
            let maxScrollPos = max(0, contentSize.height - textSize.height)
            let realScrollPos: CGFloat
            if scrollPos < 0 {
                realScrollPos = 0
            } else if scrollPos > maxScrollPos {
                realScrollPos = maxScrollPos
            } else {
                realScrollPos = scrollPos
            }
            UIView.animate(withDuration: 0.5, delay: 0, options: .allowAnimatedContent) {
                self.setContentOffset(CGPoint(x: 0, y: realScrollPos), animated: false)
            } completion: { _ in
                if self.savedSelectedRange.length <= 0 {
                    self.selectedRange = NSRange.empty(at: range.end - 1)
                } else {
                    self.selectedRange = self.savedSelectedRange
                }
            }
            setContentOffset(CGPoint(x: 0, y: realScrollPos), animated: true)
        }
        
        @objc func tapped(gestureRecognizer: UIGestureRecognizer) {
            let location = gestureRecognizer.location(in: self)
            let realLocation = location.shift(by: CGVector(dx: -textContainerInset.left, dy: -textContainerInset.top))
            let idx = layoutManager.characterIndex(for: realLocation, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
            if let (range, line) = content.chunks.search(pos: idx), let checked = line.checked {
                let lineInfo = content.lineInfo(range: range, line: line)
                let indentFold = lineInfo.indentFold(textWidth: textSize.width)
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
                        self.selectedRange = NSRange.empty(at: range.end - 1) // accounting for that "\n"
                    }
                    ptrStop[0] = true
                }
            } else {
                let linkInfo = content.linkInfo(pos: idx)
                if let guid = linkInfo.guid {
                    if let targetLine = content.linkStructure.linkTargets[guid] {
                        scrollToRange(range: targetLine.content!.text!.range)
                    } // TODO: handle the case of a broken link
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
            let linkInfo = content.linkInfo(pos: location)
            for lineInfo in content.lineInfos(charRange: NSRange.item(at: location)) {
                let (font, fontRange) = lineInfo.getCorrectFont(location - lineInfo.range.location)
                if let rangePtr = range {
                    let realFontRange = fontRange.shift(by: lineInfo.range.location)
                    if let lRange = linkInfo.linkRange {
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
                return [
                    .font: font,
                    .foregroundColor: linkInfo.color,
                    .paragraphStyle: paragraphStyle,
                    .underlineStyle: linkInfo.isLink ? NSUnderlineStyle.single.rawValue : 0
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
//            self.allowsNonContiguousLayout = true
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
