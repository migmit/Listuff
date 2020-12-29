//
//  ContentView.swift
//  Listuff
//
//  Created by MigMit on 03.11.2020.
//

import Combine
import SwiftUI
//import CoreData

var testDocument = TextState(node: Node(
    id: 0,
    text: "First node",
    children: [
        Node(
            id: 1,
            text: "Second node",
            children: [
                Node(
                    id: 2,
                    text: "Third node and some more awesome stuff"
                ),
                Node(
                    id: 3,
                    text: "Fourth node"
                )
            ]
        ),
        Node(
            id: 4,
            text: "Fifth node"
        )
    ]
))

let systemFont = UIFont.monospacedSystemFont(ofSize: UIFont.labelFontSize, weight: .regular)
let systemColor = UIColor.label
let indentationStep = 35.0
let paragraphSpacing = 5.0

struct HierarchyView: UIViewRepresentable {
    typealias UIViewType = TextView
    
    let textStorage: TextStorage
    let layoutManager: NSLayoutManager
    let textContainer: NSTextContainer

    init(content: TextState) {
        textStorage = TextStorage(content: content)
        layoutManager = NSLayoutManager()
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
            paragraphStyle.firstLineHeadIndent = paragraphIndentation
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
            switch(attachment) {
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
                ForEach(testDocument.items, id: \.0) {node in
                    Text(node.1.trimmingCharacters(in: .whitespacesAndNewlines))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .onTapGesture{
                            print(node.0)
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
