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
        Node(
            text: "Long hierarchy 1",
            linkId: "linked_node",
            children: [
                Node(
                    text: "Long hierarchy 2",
                    children: [
                        Node(
                            text: "Long hierarchy 3, with a link",
                            links: [(25..<29, "linked_chapter")],
                            children: [
                                Node(
                                    text: "Long hierarchy 4, with a broken link",
                                    links: [(25..<36, "broken_link")],
                                    children: [
                                        Node(
                                            text: "Long hierarchy 5, with two links, one broken",
                                            links: [(25..<28, "linked_chapter"), (29..<34, "broken_too")],
                                            children: [
                                                Node(
                                                    text: "Long hierarchy 6, with russian characters: абырвалг",
                                                    children: [
                                                        Node(
                                                            text: "Long hierarchy 7, with a dash and a link",
                                                            style: .dash,
                                                            links: [(30..<34, "linked_node")],
                                                            children: [
                                                                Node(
                                                                    text: "Long hierarchy 8, with a bullet, checked",
                                                                    checked: true,
                                                                    style: .bullet,
                                                                    children: [
                                                                        Node(
                                                                            text: "Long hierarchy 9, with a special symbol: ☼, numbered",
                                                                            style: .number,
                                                                            children: [
                                                                                Node(
                                                                                    text: "Long hierarchy 10, with emojis and non-ASCII characters: \u{1f602}👩‍👩‍👧‍👦éüő",
                                                                                    children: [
                                                                                        Node(
                                                                                            text: "Long hierarchy 11",
                                                                                            children: [
                                                                                                Node(text: "Long hierarchy 12")
                                                                                            ]
                                                                                        )
                                                                                    ]
                                                                                )
                                                                            ]
                                                                        ),
                                                                        Node(text: "Another numbered item, unchecked", checked: false, style: .number),
                                                                        Node(text: "Yet another numbered item", style: .number),
                                                                        Node(text: "Not numbered, but checked", checked: true),
                                                                        Node(text: "Numbered again, checked", checked: true, style: .number)
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
        Section(text: "Section", checked: true, level: .section),
        Node(text: "Section content, with a dash", style: .dash),
        Section(text: "Subsection", checked: false, level: .subsection),
        Section(text: "Chapter", checked: nil, level: .chapter),
        Node(text: "Chapter content"),
        Section(text: "Another section", checked: false, level: .section),
        Node(text: "a"),
        Node(text: "b"),
        Node(text: "c"),
        Node(text: "d"),
        Node(text: "e"),
        Node(text: "f"),
        Node(text: "g"),
        Node(text: "h"),
        Node(text: "i"),
        Node(text: "j"),
        Node(text: "k"),
        Node(text: "l"),
        Node(text: "m"),
        Node(text: "n"),
        Node(text: "o"),
        Node(text: "p"),
        Node(text: "q"),
        Node(text: "r"),
        Node(text: "s"),
        Node(text: "t"),
        Node(text: "u"),
        Section(text: "Linked chapter", level: .chapter, linkId: "linked_chapter"),
        Node(text: "v"),
        Node(text: "w"),
        Node(text: "x"),
        Node(text: "y"),
        Node(text: "z", linkId: "not_mentioned")
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
