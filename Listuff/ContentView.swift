//
//  ContentView.swift
//  Listuff
//
//  Created by MigMit on 03.11.2020.
//

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

struct Tree {
    class Item {
        var id: Int
        weak var text: WAVLTree<Item>.Node!
        var children: WAVLTree<Item> = WAVLTree()
        init(id: Int, text: String, chunks: inout WAVLTree<Item>) {
            self.id = id
            self.text = chunks.insert(value: self, length: text.count, dir: .Left, near: nil)
        }
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
}

class NodeStorage: NSTextStorage {
    let topNode: Node
    init(topNode: Node) {
        self.topNode = topNode
        super.init()
    }
    required init?(coder: NSCoder) {
        return nil
    }
}

func nodeToTree(node: Node) -> Tree {
    var tree: WAVLTree<Tree.Item> = WAVLTree()
    var text = node.text
    var root = Tree.Item(id: node.id, text: node.text, chunks: &tree)
    func appendChildren(current: inout Tree.Item, children: [Node]) {
        for child in children {
            text += child.text
            var item = Tree.Item(id: child.id, text: child.text, chunks: &tree)
            let _ = current.children.insert(value: item, length: 1, dir: .Left, near: nil)
            appendChildren(current: &item, children: child.children)
        }
    }
    appendChildren(current: &root, children: node.children)
    return Tree(text: text, chunks: tree, root: root)
}

var testDocument = nodeToTree(node: Node(
    id: 0,
    text: "First node",
    children: [
        Node(
            id: 1,
            text: "Second node\n",
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

struct HierarchyView: UIViewRepresentable {
    typealias UIViewType = TextView
    
    let textStorage: TextStorage
    let layoutManager: NSLayoutManager
    let textContainer: NSTextContainer

    init() {
        textStorage = TextStorage()
        layoutManager = NSLayoutManager()
        textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
    }
    
    func makeUIView(context: Context) -> TextView {
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
        let stored: NSMutableAttributedString
        override init() {
            stored = NSMutableAttributedString(string: "")
            super.init()
        }
        required init?(coder: NSCoder) {
            return nil
        }
        override var string: String {
            return stored.string
        }
        override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
            return stored.attributes(at: location, effectiveRange: range)
        }
        override func replaceCharacters(in range: NSRange, with str: String) {
            stored.replaceCharacters(in: range, with: str)
            edited(.editedCharacters, range: range, changeInLength: str.utf16.count - range.length)
        }
        override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
            stored.setAttributes(attrs, range: range)
            edited(.editedAttributes, range: range, changeInLength: 0)
        }
    }
}

enum ProtobufType {
    case enumeration(cases: [UInt:String])
    case message(fields: [UInt:(String, String)])
}
enum ProtobufValue {
    case varint(value: UInt)
    case fixed64(int: UInt64, float: Double)
    case string(string: String?, hex: String)
    case message(value: [(UInt, ProtobufValue)])
    case fixed32(int: UInt32, float: Float)
    static func readVarint(data: Data, offset: Int, maxLen: Int) -> (UInt, Int)? {
        var multiple: UInt = 1
        var summand: UInt = 0
        var currentOffset = offset
        while (currentOffset < maxLen) {
            let byte = data[currentOffset]
            if (byte < 128) {
                return (UInt(byte) * multiple + summand, currentOffset + 1)
            } else {
                summand += UInt(byte - 128) * multiple
                multiple <<= 7
                currentOffset += 1
            }
        }
        return nil
    }
    static func readUInt32(data: Data, offset: Int) -> UInt32 {
        var result: UInt32 = 0
        var multiple: UInt32 = 1
        for pos in 0..<4 {
            result += UInt32(data[offset+pos]) * multiple
            multiple <<= 8
        }
        return result
    }
    static func readUInt64(data: Data, offset: Int) -> UInt64 {
        var result: UInt64 = 0
        var multiple: UInt64 = 1
        for pos in 0..<8 {
            result += UInt64(data[offset+pos]) * multiple
            multiple <<= 8
        }
        return result
    }
    static func from(data: Data, offset: Int, maxLen: Int) -> (UInt, ProtobufValue, Int)? {
        if let (header, bodyOffset) = readVarint(data: data, offset: offset, maxLen: maxLen) {
            let (fieldNum, wireType) = header.quotientAndRemainder(dividingBy: 8)
            switch(wireType) {
            case 0:
                if let (value, newOffset) = readVarint(data: data, offset: bodyOffset, maxLen: maxLen) {
                    return (fieldNum, .varint(value: value), newOffset)
                } else {
                    return nil
                }
            case 1:
                guard offset + 8 <= maxLen else {return nil}
                let uint64 = readUInt64(data: data, offset: offset)
                return (fieldNum, .fixed64(int: uint64, float: Double(bitPattern: uint64)), offset + 8)
            case 2:
                if let (totalLength, messagesOffset) = readVarint(data: data, offset: bodyOffset, maxLen: maxLen) {
                    let messagesEnd = messagesOffset + Int(totalLength)
                    if let messages = arrayFrom(data: data, offset: messagesOffset, maxLen: messagesEnd) {
                        return (fieldNum, .message(value: messages), messagesEnd)
                    } else if messagesEnd <= maxLen {
                        let dataSlice = data[messagesOffset..<messagesEnd]
                        return (fieldNum, .string(string: String(data: dataSlice, encoding: .utf8), hex: dataSlice.map{String(format: "%02hhX", $0)}.joined(separator: ",")), messagesEnd)
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            case 5:
                guard offset + 4 <= maxLen else {return nil}
                let uint32 = readUInt32(data: data, offset: offset)
                return (fieldNum, .fixed32(int: uint32, float: Float(bitPattern: uint32)), offset + 4)
            default:
                return nil
            }
        } else {
            return nil
        }
    }
    static func arrayFrom(data: Data, offset: Int, maxLen: Int) -> [(UInt, ProtobufValue)]? {
        var messages: [(UInt, ProtobufValue)] = []
        var nextOffset = offset
        while nextOffset < maxLen {
            if let (fieldNum, message, newOffset) = from(data: data, offset: nextOffset, maxLen: maxLen) {
                messages.append((fieldNum, message))
                nextOffset = newOffset
            } else {
                return nil
            }
        }
        return messages
    }
    static func arrayFrom(data: Data) -> [(UInt, ProtobufValue)]? {
        return arrayFrom(data: data, offset: 0, maxLen: data.count)
    }
    func printMessage(fieldNum: UInt, expecting: (String, ProtobufType?), context: [String:ProtobufType] = [:], prefix: String) {
        let (fieldName, protobufType) = expecting
        switch(self) {
        case .varint(let value):
            var strVal = String(value)
            if case .enumeration(let cases) = protobufType, let name = cases[value] {
                strVal = name
            }
            print("\(prefix)\(fieldName) => \(strVal)")
        case .fixed64(let int, let float):
            var strVal = "\(int) or \(float)"
            if case .enumeration(let cases) = protobufType, let name = cases[UInt(int)] {
                strVal = name
            }
            print("\(prefix)\(fieldName)[64] => \(strVal)")
        case .message(let value):
            var messageType: [UInt:(String, String)] = [:]
            if case .message(let fields) = protobufType {
                messageType = fields
            }
            print("\(prefix)\(fieldName) =>")
            ProtobufValue.printArray(array: value, expecting: messageType, context: context, prefix: prefix + "  ")
            print("\(prefix)<=")
        case .string(let string, let hex):
            if let str = string {
                print("\(prefix)\(fieldNum) =>")
                print(str)
                print("<= or \(hex)")
            } else {
                print("\(prefix)\(fieldName) => \(hex)")
            }
        case .fixed32(let int, let float):
            var strVal = "\(int) or \(float)"
            if case .enumeration(let cases) = protobufType, let name = cases[UInt(int)] {
                strVal = name
            }
            print("\(prefix)\(fieldName)[32] => \(strVal)")
        }
    }
    static func searchType(fieldNum: UInt, expecting: [UInt:(String, String)], context: [String:ProtobufType]) -> (String, ProtobufType?) {
        guard let (expectedName, expectedType) = expecting[fieldNum] else {return (String(fieldNum), nil)}
        return (expectedName, context[expectedType])
    }
    static func printArray(array: [(UInt, ProtobufValue)], expecting: [UInt:(String, String)] = [:], context: [String:ProtobufType] = [:], prefix: String = "") {
        for (fieldNum, value) in array {
            value.printMessage(fieldNum: fieldNum, expecting: searchType(fieldNum: fieldNum, expecting: expecting, context: context), context: context, prefix: prefix)
        }
    }
}

class FakeNotesData: NSObject, NSCoding {
    var attributedStringData: Data?
    required init?(coder: NSCoder) {
        attributedStringData = coder.decodeObject(forKey: "attributedStringData") as? Data
    }
    func encode(with coder: NSCoder) {
        if let data = attributedStringData {coder.encode(data, forKey: "attributedStringData")}
    }
}

let debugMessageContext: [String:ProtobufType] = [
    "ChunkInfo": .message(fields: [1: ("Length", "Int"), 2: ("ParagraphStyle", "ParagraphStyle"), 5: ("TextStyle", "TextStyle")]),
    "ParagraphStyle": .message(fields: [1: ("ListStyle", "ListStyle"), 3: ("UNKNOWN", ""), 4: ("ListDepth", "Int"), 5: ("CheckedListInfo", "CheckedListInfo"), 7: ("StartFrom", "Int")]),
    "TextStyle": .enumeration(cases: [1: "Bold", 2: "Italic"]),
    "ListStyle": .enumeration(cases: [0x65: "dashed", 0x66: "numbered", 0x67: "(un)checked"]),
    "CheckedListInfo": .message(fields: [1: ("UNKNOWN", ""), 2: ("IsChecked", "Bool")]),
    "Bool": .enumeration(cases: [0: "no", 1: "yes"])
]

func debugDecodeBPList(data: Data) -> String? {
    let keyed = try! NSKeyedUnarchiver(forReadingFrom: data)
    keyed.decodingFailurePolicy = .raiseException
    keyed.requiresSecureCoding = false
    keyed.setClass(FakeNotesData.self, forClassName: "ICNotePasteboardData")
    if let obj = keyed.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? FakeNotesData,
       let attributedStringData = obj.attributedStringData
    {
        if let protobuf = ProtobufValue.arrayFrom(data: attributedStringData) {
            ProtobufValue.printArray(array: protobuf, expecting: [2:("Text", "Text"), 5:("Chunk", "ChunkInfo")], context: debugMessageContext)
        }
        return attributedStringData.map{String(format: "%02hhX", $0)}.joined(separator: ",")
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
        print(decoded)
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
            HierarchyView()
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
