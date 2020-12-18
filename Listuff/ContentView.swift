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
extension ProtobufValue {
    func printMessage(expecting: (String, String?), context: [String:ProtobufType] = [:], prefix: String) {
        let (fieldName, protobufTypeName) = expecting
        let protobufType = protobufTypeName.map{context[$0]}
        switch(self) {
        case .varint(let value, let svalue):
            var strVal = svalue >= 0 ? String(value) : "\(String(value)) (\(String(svalue)))"
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
        case .lengthLimited(let value, let string, let hex):
            if let v = value {
                print("\(prefix)\(fieldName) =>")
                ProtobufValue.printArray(array: v, expecting: protobufTypeName, context: context, prefix: prefix + "  ")
            } else {
                let hexStr = hex.map{String(format: "%02X", $0)}.joined(separator: ",")
                if let str = string {
                    print("\(prefix)\(fieldName) =>")
                    print(str)
                    print("<= or \(hexStr)")
                } else {
                    print("\(prefix)\(fieldName) => \(hexStr)")
                }
            }
        case .fixed32(let int, let float):
            var strVal = "\(int) or \(float)"
            if case .enumeration(let cases) = protobufType, let name = cases[UInt(int)] {
                strVal = name
            }
            print("\(prefix)\(fieldName)[32] => \(strVal)")
        }
    }
    static func searchType(fieldNum: UInt, expecting: String?, context: [String:ProtobufType]) -> (String, String?) {
        if let e = expecting,
           case .message(let expectingFields) = context[e],
           let result = expectingFields[fieldNum]
        {
            return result
        } else {
            return (String(fieldNum), nil)
        }
    }
    static func printArray(array: [(UInt, ProtobufValue)], expecting: String? = nil, context: [String:ProtobufType] = [:], prefix: String = "") {
        for (fieldNum, value) in array {
            value.printMessage(expecting: searchType(fieldNum: fieldNum, expecting: expecting, context: context), context: context, prefix: prefix)
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

let debugMessageContext: [String:ProtobufType] = [
    "Paste": .message(fields: [2: ("Text", ""), 5: ("Chunk", "ChunkInfo"), 6: ("Attachment", "AttachmentData")]),
    "ChunkInfo": .message(
        fields: [
            1: ("Length", "Int"),
            2: ("ParagraphInfo", "ParagraphInfo"),
            3: ("TextSize", ""),
            5: ("TextStyle", "TextStyle"),
            6: ("Underlined", "Bool"),
            7: ("Strikethrough", "Bool"),
            8: ("BaselineOffset", "Int"),
            9: ("URL", ""),
            10: ("Color", "Color"),
            12: ("Attachment", "Attachment")
        ]),
    "ParagraphInfo": .message(
        fields: [
            1: ("Style", "ParagraphStyle"),
            2: ("Alignment", "Alignment"),
            3: ("WritingDirection", "WritingDirection"),
            4: ("ListDepth", "Int"),
            5: ("CheckedListInfo", "CheckedListInfo"),
            7: ("StartFrom", "Int")
        ]),
    "TextStyle": .enumeration(cases: [1: "Bold", 2: "Italic", 3: "BoldItalic"]),
    "ParagraphStyle": .enumeration(cases: [0: "Title", 1: "Heading", 2: "Subheading", 0x64: "bulleted", 0x65: "dashed", 0x66: "numbered", 0x67: "(un)checked"]),
    "CheckedListInfo": .message(fields: [1: ("UNKNOWN", ""), 2: ("IsChecked", "Bool")]),
    "Attachment": .message(fields: [1: ("GUID", ""), 2: ("Type", "")]),
    "AttachmentData": .message(fields: [2: ("GUID", ""), 6: ("Content", ""), 8: ("Type", ""), 17: ("UNKNOWN_PTR", ""), 25: ("UNKNOWN_INT", "Int")]),
    "Color": .message(fields: [1: ("Red", "Float"), 2: ("Green", "Float"), 3: ("Blue", "Float"), 4: ("Alpha", "Float")]),
    "Alignment": .enumeration(cases: [0: "left", 1: "center", 2: "right", 3: "justify"]),
    "WritingDirection": .enumeration(cases: [0: "ltr", 1: "default", 2: "rtl"]),
    "Bool": .enumeration(cases: [0: "no", 1: "yes"])
]

let debugTableInfo: [String:ProtobufType] = [
    "TableInfo": .message(fields: [1: ("UNKNOWN", "Int"), 2: ("Content", "TableInfo1")]),
    "TableInfo1": .message(fields: [1: ("UNKNOWN", "Int"), 2: ("UNKNOWN", "Int"), 3: ("Content", "TableData")]),
    "TableData": .message(fields: [1: ("UNKNOWN", "Message"), 2: ("UNKNOWN", "Message"), 3: ("Record", "TableRecord"), 4: ("Field", ""), 5: ("Type", ""), 6: ("GUID", ""), 7: ("UNKNOWN", "Message")]),
    "TableRecord": .message(fields: [1: ("UNKNOWN", "Message"), 6: ("Dict", "Dictionary"), 10: ("Cell", "TableCell"), 13: ("Object", "TableObject"), 16: ("Positions", "PositionAssociation")]),
    "TableObject": .message(fields: [1: ("TypeId", "Int"), 3: ("Field", "ObjectField")]),
    "ObjectField": .message(fields: [1: ("Name", "Int"), 2: ("Value", "FieldValue")]),
    "FieldValue": .message(fields: [2: ("Int", "Int"), 4: ("String", ""), 6: ("Object", "Int")]),
    "TableCell": .message(fields: [2: ("Content", ""), 3: ("UNKNOWN", "Message")]),
    "Dictionary": .message(fields: [1: ("Item", "DictItem")]),
    "DictItem": .message(fields: [1: ("Key", "FieldValue"), 2: ("Value", "FieldValue"), 3: ("UNKNOWN", "Message")]),
    "PositionAssociation": .message(fields: [1: ("Positions", "PosAssoc"), 2: ("Keys", "Dictionary")]),
    "PosAssoc": .message(fields: [1: ("Positions", "PosData"), 2: ("RealIds", "Dictionary")]),
    "PosData": .message(fields: [1: ("UNKNOWN", "Message"), 2: ("Position", "PositionInfo")]),
    "PositionInfo": .message(fields: [1: ("Index", "Int"), 2: ("GUID", "")])
]

struct GzipFlags: OptionSet {
    let rawValue: UInt8
    static let text = GzipFlags(rawValue: 1 << 0)
    static let hcrc = GzipFlags(rawValue: 1 << 1)
    static let extra = GzipFlags(rawValue: 1 << 2)
    static let name = GzipFlags(rawValue: 1 << 3)
    static let comment = GzipFlags(rawValue: 1 << 4)
}

func debugGunzip(gzipped: Data) -> Data? {
    var dataOffset = 10
    guard dataOffset <= gzipped.count - 8 else {return nil}
    let flags = GzipFlags(rawValue: gzipped[3])
    if flags.contains(.extra) {
        let xlen = Int(gzipped[dataOffset]) + Int(gzipped[dataOffset+1]) * 256
        dataOffset += xlen + 2
        guard dataOffset <= gzipped.count - 8 else {return nil}
    }
    if flags.contains(.name) {
        while gzipped[dataOffset] != 0 && dataOffset < gzipped.count {dataOffset += 1}
        dataOffset += 1
        guard dataOffset <= gzipped.count - 8 else {return nil}
    }
    if flags.contains(.comment) {
        while gzipped[dataOffset] != 0 && dataOffset < gzipped.count {dataOffset += 1}
        dataOffset += 1
        guard dataOffset <= gzipped.count - 8 else {return nil}
    }
    return (try? (gzipped[dataOffset..<gzipped.count-8] as NSData).decompressed(using: .zlib)) as Data?
}

func debugTranspose<T>(source: [[T]]) -> [[T]] {
    var result: [[T]] = []
    if !source.isEmpty {
        result = source[0].map{[$0]}
        for row in source[1..<source.count] {
            var temp: [[T]] = []
            for (resultRow, elt) in zip(result, row) {
                temp.append(resultRow + [elt])
            }
            result = temp
        }
    }
    return result
}

func debugDecodeBPList(data: Data) -> String? {
    guard let keyed = try? NSKeyedUnarchiver(forReadingFrom: data) else {return nil}
    keyed.decodingFailurePolicy = .raiseException
    keyed.requiresSecureCoding = false
    keyed.setClass(FakeNotesData.self, forClassName: "ICNotePasteboardData")
    keyed.setClass(FakeDataPersister.self, forClassName: "ICDataPersister")
    if let obj = keyed.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? FakeNotesData,
       let attributedStringData = obj.attributedStringData
    {
        let attachmentDict = obj.dataPersister?.identifierToDataDictionary as? [String: Data] ?? [:]
        let tableDict = attachmentDict.compactMapValues{value -> [[String]]? in
            guard let gunzipped = debugGunzip(gzipped: value) else {return nil}
            guard let pv = ProtobufValue.arrayFrom(data: gunzipped) else {return nil}
            guard let table = NotesTable(source: ProtobufValue.lengthLimited(value: pv, string: nil, hex: gunzipped).normalize()) else {return nil}
            guard let decoded = DecodedTable(source: table) else {return nil}
            return decoded.cells
        }
        if let protobuf = ProtobufValue.arrayFrom(data: attributedStringData) {
            ProtobufValue.printArray(array: protobuf, expecting: "Paste", context: debugMessageContext)
        }
        for (k, v) in tableDict {
            print(k)
            for row in debugTranspose(source: v) {
                print(row)
            }
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
