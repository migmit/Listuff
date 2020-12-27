//
//  ContentView.swift
//  Listuff
//
//  Created by MigMit on 03.11.2020.
//

import Combine
import SwiftUI
//import CoreData

struct Node {
    var id: Int
    var text: String
    var children: [Node] = []
    
    func allNodes() -> [Node] {
        var result = [self]
        for child in children {
            result = result + child.allNodes()
        }
        return result
    }
}

class TextState {
    typealias Dir = WAVLTree<Item>.Dir
    typealias Chunk = WAVLTree<Item>.Node
    typealias EventPublisher = AnyPublisher<Event, Never>
    class Item {
        var id: Int
        weak var text: WAVLTree<Item>.Node!
        var children: WAVLTree<Item> = WAVLTree()
        weak var parent: Item?
        init(id: Int, text: String, chunks: inout WAVLTree<Item>, parent: Item?) {
            self.id = id
            self.text = chunks.insert(value: self, length: text.utf16.count, dir: .Left, near: nil).0
            self.parent = parent
        }
        var depth: Int {
            var result = 0
            var current = self
            while let p = current.parent {
                result += 1
                current = p
            }
            return result
        }
    }
    enum Event {
        case Insert(node: Chunk, range: NSRange)
        case Remove(value: Item, oldRange: NSRange)
        case SetLength(value: Item, length: Int, oldRange: NSRange)
    }
    struct ListItemInfo {
        let range: NSRange
        let depth: Int
    }
    var text: String
    var chunks: WAVLTree<Item>
    var root: Item
    var items: [(Int, Substring)] {
        var result: [(Int, Substring)] = []
        for (bounds, item) in chunks {
            if let r = Range(bounds, in: text) {
                result.append((item.id, text[r]))
            }
        }
        return result
    }
    private let eventsPublisher = PassthroughSubject<Event, Never>()
    var events: EventPublisher {
        return eventsPublisher.eraseToAnyPublisher()
    }
    init(text: String, chunks: WAVLTree<Item>, root: Item) {
        self.text = text
        self.chunks = chunks
        self.root = root
    }
    init(node: Node) {
        var chunks: WAVLTree<Item> = WAVLTree()
        var text = node.text + "\n"
        var root = Item(id: node.id, text: text, chunks: &chunks, parent: nil)
        func appendChildren(current: inout Item, children: [Node]) {
            for child in children {
                let childText = child.text + "\n"
                text += childText
                var item = Item(id: child.id, text: childText, chunks: &chunks, parent: current)
                let _ = current.children.insert(value: item, length: 1, dir: .Left, near: nil)
                appendChildren(current: &item, children: child.children)
            }
        }
        appendChildren(current: &root, children: node.children)
        self.text = text
        self.chunks = chunks
        self.root = root
    }
    func setChunkLength(node: Chunk, length: Int) -> NSRange {
        let range = WAVLTree.setLength(node: node, length: length)
        eventsPublisher.send(.SetLength(value: node.value, length: length, oldRange: range))
        return range
    }
    func insertChunk(value: Item, length: Int, dir: Dir = .Right, near: Chunk? = nil) -> (Chunk, Int) {
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
    func listItemInfo(pos: Int) -> ListItemInfo? {
        return chunks.search(pos: pos).map{ListItemInfo(
            range: $0.0,
            depth: $0.1.depth
        )}
    }
}

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

struct Test {
    var text: String
    mutating func update() {}
}

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

class FakeDataPersister: NSObject, NSCoding {
    var identifierToDataDictionary: NSDictionary?
    required init?(coder: NSCoder) {
        identifierToDataDictionary = coder.decodeObject(forKey: "identifierToDataDictionary") as? NSDictionary
    }
    func encode(with coder: NSCoder) {
        if let dict = identifierToDataDictionary {coder.encode(dict, forKey: "identifierToDataDictionary")}
    }
}

class FakeNotesData: NSObject, NSCoding {
    var attributedStringData: Data?
    var dataPersister: FakeDataPersister?
    required init?(coder: NSCoder) {
        attributedStringData = coder.decodeObject(forKey: "attributedStringData") as? Data
        dataPersister = coder.decodeObject(forKey: "dataPersister") as? FakeDataPersister
    }
    func encode(with coder: NSCoder) {
        if let data = attributedStringData {coder.encode(data, forKey: "attributedStringData")}
        if let persister = dataPersister {coder.encode(persister, forKey: "dataPersister")}
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
            case .table(let table):
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

func debugDecodeBPList(data: Data) -> Note? {
    guard let keyed = try? NSKeyedUnarchiver(forReadingFrom: data) else {return nil}
    keyed.decodingFailurePolicy = .raiseException
    keyed.requiresSecureCoding = false
    keyed.setClass(FakeNotesData.self, forClassName: "ICNotePasteboardData")
    keyed.setClass(FakeDataPersister.self, forClassName: "ICDataPersister")
    if let obj = keyed.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? FakeNotesData,
       let attributedStringData = obj.attributedStringData {
        return Note(source: ProtoValue.lengthLimited(value: ProtoMessage(value: attributedStringData[0..<attributedStringData.count])), attachments: obj.dataPersister?.identifierToDataDictionary)
    } else {
        return nil
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
    if let data = pb.data(forPasteboardType: "com.apple.notes.richtext"), let decoded = debugDecodeBPList(data: data) {
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
    
    let test = ObservableProxy(value: Test(text: "Hello World"))
    
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
