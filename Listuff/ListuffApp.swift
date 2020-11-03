//
//  ListuffApp.swift
//  Listuff
//
//  Created by MigMit on 03.11.2020.
//

import SwiftUI

@main
struct ListuffApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
