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
            text: "First node",
            children: [
                Node(
                    text: "Second node",
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
                        Node(text: "First child oeiuryhg qoieurhg oqeiyruhg qoeiurygh qoeiuryghq oeirugh qpeirugh pqieurhg pqeiurhg pqeiurgh pqeiurgh pqieurhg qpeiurhg pqieurhqg", checked: false),
                        Node(text: "Second child oeiuryhg qoieurhg oqeiyruhg qoeiurygh qoeiuryghq oeirugh qpeirugh pqieurhg pqeiurhg pqeiurgh pqeiurgh pqieurhg qpeiurhg pqieurhqg", checked: true)
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
        )
    ]
)

let systemFont = UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
let systemColor = UIColor.label
let indentationStep = 35.0
let paragraphSpacing = 5.0
let checkmark = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .medium))!.withTintColor(UIColor.systemGreen)
let unchecked = UIImage(systemName: "circle", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .medium))!.withTintColor(UIColor.systemGray2)
let checkmarkWidth = max(checkmark.size.width, unchecked.size.width)
let checkmarkPadding = CGFloat(5.0)
let checkmarkHeight = max(checkmark.size.height, unchecked.size.height)
let bullet = "◦"
let dash = "-"

struct HierarchyView: UIViewRepresentable {
    typealias UIViewType = TextView
    
    let textStorage: TextStorage
    let layoutManager: NSLayoutManager
    let textContainer: NSTextContainer

    init(content: TextState) {
        textStorage = TextStorage(content: content)
        layoutManager = LayoutManager(content: content)
        textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
    }
    
    func makeUIView(context: Context) -> TextView {
        if layoutManager.textStorage == nil {
            textStorage.addLayoutManager(layoutManager)
        }
        if textContainer.layoutManager == nil {
            layoutManager.addTextContainer(textContainer)
        }
        let view = TextView(frame: .zero, textContainer: textContainer)
        return view
    }
    
    func updateUIView(_ uiView: TextView, context: Context) {
    }
    
    class TextView: UITextView {
        override init(frame: CGRect, textContainer: NSTextContainer?) {
            super.init(frame: frame, textContainer: textContainer)
        }
        
        required init?(coder: NSCoder) {
            return nil
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
            guard let listItemInfo = content.listItemInfo(pos: location) else {
                NSException(name: .rangeException, reason: "Position \(location) out of bounds", userInfo: [:]).raise()
                return [:] // Never happens
            }
            if let rangePtr = range {
                rangePtr[0] = listItemInfo.range
            }
            let paragraphIndentation = CGFloat(Double(listItemInfo.depth) * indentationStep)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = listItemInfo.checked == nil ? paragraphIndentation : (paragraphIndentation + checkmarkWidth + checkmarkPadding * 2)
            if listItemInfo.checked != nil {
                paragraphStyle.minimumLineHeight = checkmarkHeight
            }
            paragraphStyle.headIndent = paragraphIndentation
            paragraphStyle.paragraphSpacing = CGFloat(paragraphSpacing)
            return [
                .font: systemFont,
                .foregroundColor: systemColor,
                .paragraphStyle: paragraphStyle
            ]
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
        override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
            for (range, line) in content.chunks.covering(from: charRange.location, to: charRange.location + charRange.length) {
                if let checked = line.checked {
                    let glRange = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    if glRange.length <= 0 {continue}
                    let image = checked.value ? checkmark : unchecked
                    enumerateLineFragments(forGlyphRange: NSMakeRange(glRange.location, 1)) {_, usedRect, textContainer, _, ptrStop in
                        let imageOrigin = CGPoint(
                            x: usedRect.origin.x - checkmarkPadding - (checkmarkWidth + image.size.width) / 2 + textContainer.lineFragmentPadding + origin.x,
                            y: usedRect.origin.y + (usedRect.size.height - image.size.height) / 2 + origin.y
                        )
                        image.draw(at: imageOrigin)
                        ptrStop.pointee = true
                    }
                    
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
