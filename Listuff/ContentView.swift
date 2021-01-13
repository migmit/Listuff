//
//  ContentView.swift
//  Listuff
//
//  Created by MigMit on 03.11.2020.
//

import SwiftUI
//import CoreData

var testDocument = TextState(
    appendables: [
        Section(text: "Section", checked: true, level: .section),
        Section(text: "Subsection", checked: false, level: .subsection),
        Node(
            text: "First node \u{1f602}👩‍👩‍👧‍👦éüő",
            children: [
                Node(
                    text: "☼😂éüő Second node",
                    children: [
                        Node(text: "Third node and some more awesome stuff", style: .bullet),
                        Node(text: "Fourth node", checked: true, style: .dash)
                    ]
                ),
                Node(text: "Fifth node")
            ]
        ),
        Section(text: "Chapter", checked: nil, level: .chapter),
        Section(text: "Another section", checked: false, level: .section),
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
                Node(text: "Third item", style: .number),
                Node(text: "Back to normal")
            ]
        ),
        Node(
            text: "Another numbered list:",
            children: [
                Node(text: "Wait for it..."),
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
        Node(
            text: "Long hierarchy 1",
            children: [
                Node(
                    text: "Long hierarchy 2",
                    children: [
                        Node(
                            text: "Long hierarchy 3",
                            children: [
                                Node(
                                    text: "Long hierarchy 4",
                                    children: [
                                        Node(
                                            text: "Long hierarchy 5",
                                            children: [
                                                Node(
                                                    text: "Long hierarchy 6",
                                                    children: [
                                                        Node(
                                                            text: "Long hierarchy 7",
                                                            children: [
                                                                Node(
                                                                    text: "Long hierarchy 8",
                                                                    children: [
                                                                        Node(
                                                                            text: "Long hierarchy 9",
                                                                            children: [
                                                                                Node(
                                                                                    text: "Long hierarchy 10",
                                                                                    children: [
                                                                                        Node(
                                                                                            text: "Long hierarchy 11",
                                                                                            children: [
                                                                                                Node(
                                                                                                    text: "Long hierarchy 12",
                                                                                                    children: [
                                                                                                        Node(
                                                                                                            text: "Long hierarchy 13",
                                                                                                            children: [
                                                                                                                Node(
                                                                                                                    text: "Long hierarchy 14",
                                                                                                                    children: [
                                                                                                                        Node(text: "Long hierarchy 15", checked: true, style: .bullet)
                                                                                                                    ]
                                                                                                                )
                                                                                                            ]
                                                                                                        )
                                                                                                    ]
                                                                                                )
                                                                                            ]
                                                                                        )
                                                                                    ]
                                                                                )
                                                                            ]
                                                                        )
                                                                    ]
                                                                )
                                                            ]
                                                        )
                                                    ]
                                                )
                                            ]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
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
    str.enumerateAttributes(in: str.fullRange, options: []) {attrs, range, _ in
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
    
    @State var showSidebar: Bool = true
    
    var body: some View {
        SidebarView(showSidebar: $showSidebar) {
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
            .padding(.trailing, 5)
            .controls {
                Text("Outline").font(.headline)
            }
            HierarchyView(content: testDocument)
                .controls{
                    Button(action: {withAnimation{showSidebar.toggle()}}) {
                        Image(systemName: showSidebar ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                    Spacer()
                    Text("Structure").font(.headline)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "list.bullet.indent")
                    }
                }
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
