//
//  TextView.swift
//  Listuff
//
//  Created by MigMit on 09.01.2021.
//

import SwiftUI

struct HierarchyView: UIViewRepresentable {
    typealias UIViewType = TextView
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
    
    let content: TextState
    
    init(content: TextState) {
        self.content = content
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> TextView {
        return TextView(frame: .zero, content: content, context: context)
    }
    
    func updateUIView(_ uiView: TextView, context: Context) {
    }
    
    class TextView: UITextView, UIGestureRecognizerDelegate {
        let content: TextState
        let storage: TextStorage
        let manager: LayoutManager
        let container: NSTextContainer
        var gesture: UIGestureRecognizer? = nil
        init(frame: CGRect, content: TextState, context: Context) {
            self.content = content
            self.storage = TextStorage(content: content)
            self.manager = LayoutManager(content: content)
            self.container = NSTextContainer()
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
        
        @objc func tapped(gestureRecognizer: UIGestureRecognizer) {
            let location = gestureRecognizer.location(in: self)
            let realLocation = location.shift(by: CGVector(dx: -textContainerInset.left, dy: -textContainerInset.top))
            let idx = layoutManager.characterIndex(for: realLocation, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
            if let (range, line) = content.chunks.search(pos: idx), let checked = line.checked {
                let lineInfo = content.lineInfo(range: range, line: line)
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
                    if imageRect.contains(realLocation) {
                        line.checked = TextState.Doc.Checked(value: !checked.value)
                        self.layoutManager.invalidateDisplay(forGlyphRange: correctedGlyphRange)
                        self.selectedRange = NSRange.empty(at: range.end - 1) // accounting for the final '\n'
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
        init(content: TextState) {
            self.content = content
            super.init()
        }
        required init?(coder: NSCoder) {
            return nil
        }
        override var string: String {
            return content.text
        }
        override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
            for lineInfo in content.lineInfos(charRange: NSRange.item(at: location)) {
                let (font, fontRange) = lineInfo.getCorrectFont(location - lineInfo.range.location)
                if let rangePtr = range {
                    rangePtr[0] = fontRange.shift(by: lineInfo.range.location)
                }
                let paragraphStyle = NSMutableParagraphStyle()
                if lineInfo.checkmark != nil {
                    paragraphStyle.minimumLineHeight = content.checkmarkSize.height
                }
                paragraphStyle.headIndent = lineInfo.textIndent
                paragraphStyle.firstLineHeadIndent = lineInfo.firstLineIndent
                paragraphStyle.paragraphSpacing = CGFloat(content.paragraphSpacing)
                return [
                    .font: font,
                    .foregroundColor: content.systemColor,
                    .paragraphStyle: paragraphStyle
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
        init(content: TextState) {
            self.content = content
            super.init()
            self.allowsNonContiguousLayout = true
        }
        required init?(coder: NSCoder) {
            return nil
        }
        func drawAccessory(accessory: TextState.Accessory, origin: CGPoint, boxYPos: CGFloat, boxHeight: CGFloat, fragmentPadding: CGFloat) {
            switch accessory {
            case .bullet(value: let value, indent: let indent, height: let height, font: let font):
                value.draw(at: origin.shift(by: CGVector(dx: indent, dy: boxYPos + (boxHeight - height) / 2)), withAttributes: [.font: font])
            case .number(value: let value, indent: let indent, width: let width, font: let font):
                let parStyle = NSMutableParagraphStyle()
                parStyle.alignment = .right
                let numRect = CGRect(x: indent + fragmentPadding + origin.x, y: boxYPos + origin.y, width: width, height: boxHeight)
                value.draw(in: numRect, withAttributes: [.font: font, .paragraphStyle: parStyle])
            }
        }
        override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            for lineInfo in content.lineInfos(charRange: characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)) {
                let glRange = glyphRange(forCharacterRange: lineInfo.range, actualCharacterRange: nil)
                if glRange.length <= 0 {continue}
                enumerateLineFragments(forGlyphRange: glRange.firstItem) {_, usedRect, textContainer, _, ptrStop in
                    let fragmentPadding = textContainer.lineFragmentPadding
                    if let accessory = lineInfo.accessory {
                        self.drawAccessory(accessory: accessory, origin: origin, boxYPos: usedRect.origin.y, boxHeight: usedRect.size.height, fragmentPadding: fragmentPadding)
                    }
                    if let checkmark = lineInfo.checkmark {
                        let imageOrigin = origin.shift(by: CGVector(
                            dx: lineInfo.textIndent + fragmentPadding,
                            dy: usedRect.midY - checkmark.size.height / 2
                        ))
                        checkmark.draw(at: imageOrigin)
                        ptrStop[0] = true
                    }
//                    let gc = UIGraphicsGetCurrentContext()!
//                    UIColor.green.set()
//                    gc.addRect(CGRect(origin: CGPoint(x: usedRect.minX + origin.x, y: usedRect.minY + origin.y), size: usedRect.size))
//                    gc.strokePath()
                }
            }
        }
    }
}
