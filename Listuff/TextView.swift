//
//  TextView.swift
//  Listuff
//
//  Created by MigMit on 09.01.2021.
//

import Combine
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
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate, UITextViewDelegate {
        var textView: TextView? = nil
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            textView?.saveSelectedRange()
            return true
        }
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            textView?.didSetContentOffset()
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
    
    class TextView: UITextView {
        let content: TextState
        let storage: TextStorage
        let manager: LayoutManager
        let container: NSTextContainer
        var gesture: UIGestureRecognizer? = nil
        var textWidth: CGFloat
        var savedSelectedRange: NSRange? = nil
        var targetRect: CGRect? = nil
        var targetPosition: Int? = nil
        var linkTargetShade: UIView
        var linkJumpAnimation: UIViewAnimating? = nil
        var cancellableSet: Set<AnyCancellable> = []
        init(frame: CGRect, content: TextState, textWidth: CGFloat, context: Context) {
            self.content = content
            self.storage = TextStorage(content: content, textWidth: textWidth)
            self.manager = LayoutManager(content: content, textWidth: textWidth)
            self.container = NSTextContainer()
            self.textWidth = textWidth
            self.storage.addLayoutManager(self.manager)
            self.manager.addTextContainer(self.container)
            self.linkTargetShade = UIView()
            super.init(frame: frame, textContainer: container)
            self.linkTargetShade.isUserInteractionEnabled = false
            self.linkTargetShade.layer.cornerRadius = 10.0
            self.linkTargetShade.layer.masksToBounds = true
            self.linkTargetShade.isHidden = true
            self.linkTargetShade.backgroundColor = UIColor.yellow.withAlphaComponent(0)
            self.linkTargetShade.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            self.addSubview(self.linkTargetShade)
            context.coordinator.textView = self
            self.delegate = context.coordinator
            let gesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
            self.gesture = gesture
            gesture.delegate = context.coordinator
            self.addGestureRecognizer(gesture)
            NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
                .sink{_ in self.dynamicTypeChanged()}
                .store(in: &cancellableSet)
        }
        
        required init?(coder: NSCoder) {
            return nil
        }
        
        func saveSelectedRange() {
            savedSelectedRange = selectedRange
        }
        
        func updateTextWidth(textWidth: CGFloat) {
            self.textWidth = textWidth
            storage.updateTextWidth(textWidth: textWidth)
            manager.updateTextWidth(textWidth: textWidth)
            linkAnimationCleanup()
        }
        
        func dynamicTypeChanged() {
            linkAnimationCleanup()
            content.invalidate()
            let range = NSMakeRange(0, content.text.utf16.count)
            layoutManager.processEditing(for: textStorage, edited: .editedAttributes, range: range, changeInLength: 0, invalidatedRange: range)
        }
        
        func linkAnimationCleanup() {
            linkJumpAnimation?.stopAnimation(true)
            linkTargetShade.backgroundColor = UIColor.yellow.withAlphaComponent(0)
            linkTargetShade.isHidden = true
            linkJumpAnimation = nil
        }
        
        func didSetContentOffset() {
            if let savedRange = savedSelectedRange {
                savedSelectedRange = nil
                if (savedRange.length > 0) {
                    selectedRange = savedRange
                } else if let targetPos = targetPosition {
                    targetPosition = nil
                    selectedRange = NSRange.empty(at: max(0, targetPos))
                }
            }
            if let trect = targetRect {
                targetRect = nil
                linkAnimationCleanup()
                linkTargetShade.isHidden = false
                linkTargetShade.frame = trect.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
                self.linkTargetShade.backgroundColor = UIColor.yellow.withAlphaComponent(0.6)
                let reverseAnimation = UIViewPropertyAnimator(duration: 0.9, curve: .easeIn) {
                    self.linkTargetShade.backgroundColor = UIColor.yellow.withAlphaComponent(0)
                }
                reverseAnimation.addCompletion{_ in
                    self.linkAnimationCleanup()
                }
                self.linkJumpAnimation = reverseAnimation
                reverseAnimation.startAnimation()
            }
        }
        
        func getLastGlyphIndex(box: CGRect) -> Int? {
            var result = 0
            manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(forBoundingRect: box, in: container)) {_, usedRect, _, glyphRange, _ in
                if usedRect.maxY <= box.maxY {
                    result = max(result, glyphRange.end)
                }
            }
            return result > 0 ? result : nil
        }
        
        func jumpToRange(range: NSRange) {
            // Ending TC means "in text container coordinates"
            // Ending SV means "in scroll view coordinates"
            let boundingBoxTC = manager.boundingRect(forGlyphRange: manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
            let viewFrameTC = bounds.offsetBy(dx: -textContainerInset.left, dy: -textContainerInset.top)
            let scrollPosTC: CGFloat
            if boundingBoxTC.minY >= viewFrameTC.minY && boundingBoxTC.maxY <= viewFrameTC.maxY {
                scrollPosTC = viewFrameTC.minY // contentOffset is in scroll view coordinates
            } else if boundingBoxTC.height > viewFrameTC.height {
                scrollPosTC = boundingBoxTC.minY
            } else if boundingBoxTC.height > viewFrameTC.height / 2 {
                scrollPosTC = boundingBoxTC.maxY - viewFrameTC.height
            } else {
                scrollPosTC = boundingBoxTC.minY - viewFrameTC.height / 2
            }
            let realScrollPosSV = min(contentSize.height - viewFrameTC.height, max(0, scrollPosTC + textContainerInset.top))
            let scrollChange = realScrollPosSV - contentOffset.y
            let visibleBoxTC = viewFrameTC.offsetBy(dx: 0, dy: scrollChange).intersection(boundingBoxTC)
            targetPosition = visibleBoxTC.isEmpty ? nil : getLastGlyphIndex(box: visibleBoxTC).map{manager.characterIndexForGlyph(at: $0-1)}
            targetRect = boundingBoxTC
            if scrollChange > -5 && scrollChange < 5 {
                setContentOffset(CGPoint(x: 0, y: realScrollPosSV), animated: false)
                didSetContentOffset()
            } else {
                setContentOffset(CGPoint(x: 0, y: realScrollPosSV), animated: true)
            }
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
                        self.selectedRange = NSRange.empty(at: range.end - 1) // accounting for that "\n"
                    }
                    ptrStop[0] = true
                }
            } else {
                let linkInfo = content.linkInfo(pos: idx)
                if let guid = linkInfo.guid {
                    if let targetLine = content.linkStructure.linkTargets[guid] {
                        jumpToRange(range: targetLine.content!.text!.range)
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
