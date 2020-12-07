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
    var children: WAVLTree<Node> = WAVLTree()
    
    func allNodes() -> [Node] {
        var result = [self]
        for (_, child) in children {
            result = result + child.allNodes()
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

func arrayToWAVL<V>(_ source: [V]) -> WAVLTree<V> {
    var result = WAVLTree<V>()
    for item in source {
        let _ = result.insert(value: item, length: 1, dir: .Left)
    }
    return result
}

var testDocument = Node(
    id: 0,
    text: "First node",
    children: arrayToWAVL([
        Node(
            id: 1,
            text: "Second node\n",
            children: arrayToWAVL([
                Node(
                    id: 2,
                    text: "Third node and some more awesome stuff"
                ),
                Node(
                    id: 3,
                    text: "Fourth node"
                )
            ])
        ),
        Node(
            id: 4,
            text: "Fifth node"
        )
    ])
)

struct Test {
    var text: String
    mutating func update() {}
}

struct SubView: View {
    @ObservedObject var test: ObservableProxy<Test>
    var body: some View {
        {() -> Text in
            print("Updating")
            return Text("\(test.value.text)")
        }()
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
                ForEach(testDocument.allNodes(), id: \.id) {node in
                    Text(node.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .onTapGesture{
                            print(node.id)
                        }
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarTitle("Outline", displayMode: .inline)
            List {
                SubView(test: test)
                Button("Update") {
                    test.value.update()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
        }
//        List {
//            ForEach(items) { item in
//                Text("Item at \(item.timestamp!, formatter: itemFormatter)")
//            }
//            .onDelete(perform: deleteItems)
//        }
//        .toolbar {
//            #if os(iOS)
//            EditButton()
//            #endif
//
//            Button(action: addItem) {
//                Label("Add Item", systemImage: "plus")
//            }
//        }
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
