//
//  ContentView.swift
//  Listuff
//
//  Created by MigMit on 03.11.2020.
//

import Combine
import SwiftUI
//import CoreData

var testDocument = TextState(
    nodes: [
        Node(
            text: "First node \u{1f602}éüő",
            children: [
                Node(
                    text: "😂éüő Second node",
                    children: [
                        Node(text: "Third node and some more awesome stuff", style: .bullet),
                        Node(text: "Fourth node", checked: true, style: .dash)
                    ]
                ),
                Node(text: "Fifth node")
            ]
        ),
        Node(
            text: "Numbered list:",
            children: [
                Node(
                    text: "First item",
                    children: [
                        Node(text: "First child oeiuryhg qoieurhg oqeiyruhg qoeiurygh qoeiuryghq oeirugh qpeirugh pqieurhg pqeiurhg pqeiurgh pqeiurgh pqieurhg qpeiurhg pqieurhqw", checked: false),
                        Node(text: "Second child oeiuryhg qoieurhg oqeiyruhg qoeiurygh qoeiuryghq oeirugh qpeirugh pqieurhg pqeiurhg pqeiurgh pqeiurgh pqieurhg qpeiurhg pqieurhqw", checked: true),
                        Node(text: "Third child")
                    ],
                    style: .number
                ),
                Node(text: "Second item", style: .number),
                Node(text: "Back to normal")
            ]
        ),
        Node(
            text: "Another numbered list:",
            children: [
                Node(
                    text: "Wait for it..."
                ),
                Node(text: "Another first item", style: .number),
                Node(
                    text: "Another second item",
                    children: [
                        Node(text: "Another first child", checked: false, style: .number),
                        Node(text: "Another second child", style: .number)
                    ],
                    style: .number
                ),
                Node(text: "Back to normal again")
            ]
        ),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa"),
        Node(text: "aaa")
    ]
)

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
            let realLocation = CGPoint(x: location.x - textContainerInset.left, y: location.y - textContainerInset.top)
            let idx = layoutManager.characterIndex(for: realLocation, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
            if let (range, line) = content.chunks.search(pos: idx), let checked = line.checked {
                let lineInfo = content.lineInfo(range: range, line: line)
                let glRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if glRange.length <= 0 {return}
                let correctedGlyphRange = NSMakeRange(glRange.location, 1)
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
                        self.selectedRange = NSMakeRange(range.location + range.length - 1, 0)
                    }
                    ptrStop.assign(repeating: true, count: 1)
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
            for lineInfo in content.lineInfos(charRange: NSMakeRange(location, 1)) {
                if let rangePtr = range {
                    rangePtr[0] = lineInfo.range
                }
                let paragraphStyle = NSMutableParagraphStyle()
                if lineInfo.checkmark != nil {
                    paragraphStyle.minimumLineHeight = content.checkmarkSize.height
                }
                paragraphStyle.headIndent = lineInfo.textIndent
                paragraphStyle.firstLineHeadIndent = lineInfo.firstLineIndent
                paragraphStyle.paragraphSpacing = CGFloat(content.paragraphSpacing)
                return [
                    .font: content.systemFont,
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
                (value as NSString).draw(at: CGPoint(x: indent + origin.x, y: boxYPos + (boxHeight - height) / 2 + origin.y), withAttributes: [.font: font])
            case .number(value: let value, indent: let indent, width: let width, font: let font):
                let parStyle = NSMutableParagraphStyle()
                parStyle.alignment = .right
                let numRect = CGRect(x: indent + fragmentPadding + origin.x, y: boxYPos + origin.y, width: width, height: boxHeight)
                (value as NSString).draw(in: numRect, withAttributes: [.font: font, .paragraphStyle: parStyle])
            }
        }
        override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            for lineInfo in content.lineInfos(charRange: characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)) {
                let glRange = glyphRange(forCharacterRange: lineInfo.range, actualCharacterRange: nil)
                if glRange.length <= 0 {continue}
                enumerateLineFragments(forGlyphRange: NSMakeRange(glRange.location, 1)) {_, usedRect, textContainer, _, ptrStop in
                    let fragmentPadding = textContainer.lineFragmentPadding
                    if let accessory = lineInfo.accessory {
                        self.drawAccessory(accessory: accessory, origin: origin, boxYPos: usedRect.origin.y, boxHeight: usedRect.size.height, fragmentPadding: fragmentPadding)
                    }
                    if let checkmark = lineInfo.checkmark {
                        let imageOrigin = CGPoint(
                            x: lineInfo.textIndent + origin.x + fragmentPadding,
                            y: usedRect.midY + origin.y - checkmark.size.height / 2
                        )
                        checkmark.draw(at: imageOrigin)
                        ptrStop.assign(repeating: true, count: 1)
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

func debugPrintNote(note: Note, prefix: String = "") {
    print("\(prefix)String: \(note.content)")
    for chunk in note.chunks {
        print("\(prefix)Chunk: \(chunk.length) characters")
        if let ts = chunk.textSize {print("\(prefix)  Text size: \(ts)")}
        var textStyle = ""
        if chunk.textStyle.contains(.bold) {textStyle += " bold"}
        if chunk.textStyle.contains(.italic) {textStyle += " italic"}
        if chunk.textStyle.contains(.underlined) {textStyle += " underlined"}
        if chunk.textStyle.contains(.strikethrough) {textStyle += " strikethrough"}
        if !textStyle.isEmpty {print("\(prefix)  Text style:\(textStyle)")}
        if let ps = chunk.paragraphStyle {
            print("\(prefix)  Paragraph type: \(ps.paragraphType)")
            print("\(prefix)  Alignment: \(ps.alignment)")
            print("\(prefix)  Writing direction: \(ps.writingDirection)")
            print("\(prefix)  List depth: \(ps.listDepth)")
        }
        if (chunk.baselineOffset != 0) {print("\(prefix)  Baseline offset: \(chunk.baselineOffset)")}
        if let url = chunk.linkUrl {print("\(prefix)  Link: \(url)")}
        if let color = chunk.color {print("\(prefix)  Color: \(color)")}
        if let attachment = chunk.attachment {
            switch attachment {
            case .table(table: let table):
                print("\(prefix)  Table:")
                for row in table {
                    print("\(prefix)    Row:")
                    for cell in row {
                        if let c = cell {
                            debugPrintNote(note: c, prefix: prefix + "      ")
                        } else {
                            print("\(prefix)      <Empty cell>")
                        }
                    }
                }
            }
        }
    }
}

func debugPrintAttributedString(str: NSAttributedString) {
    print("STRING: \(str.string)")
    str.enumerateAttributes(in: NSMakeRange(0, str.length), options: []) {attrs, range, _ in
        print("ATTRS for \(range): \(attrs)")
    }
}

func debugPaste() {
    let pb = UIPasteboard.general
    if pb.hasStrings {
        print("String: \(pb.string ?? "")")
    }
    if let data = pb.data(forPasteboardType: "com.apple.notes.richtext"), let decoded = decodeNote(data: data) {
        debugPrintNote(note: decoded)
    }
}

struct ContentView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//
//    @FetchRequest(
//        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
//        animation: .default)
//    private var items: FetchedResults<Item>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(testDocument.items, id: \.self) {node in
                    HStack {
                        Text(node.trimmingCharacters(in: .whitespacesAndNewlines))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }.contentShape(Rectangle())
                    .onTapGesture{
                        print(node)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarTitle("Outline", displayMode: .inline)
            HierarchyView(content: testDocument)
                .navigationBarHidden(true)
        }
    }

//    private func addItem() {
//        withAnimation {
//            let newItem = Item(context: viewContext)
//            newItem.timestamp = Date()
//
//            do {
//                try viewContext.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nsError = error as NSError
//                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//            }
//        }
//    }
//
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            offsets.map { items[$0] }.forEach(viewContext.delete)
//
//            do {
//                try viewContext.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nsError = error as NSError
//                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//            }
//        }
//    }
}

//private let itemFormatter: DateFormatter = {
//    let formatter = DateFormatter()
//    formatter.dateStyle = .short
//    formatter.timeStyle = .medium
//    return formatter
//}()

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//    }
//}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView().previewDevice(PreviewDevice(rawValue: "iPad Pro (9.7-inch)"))
//    }
//}
