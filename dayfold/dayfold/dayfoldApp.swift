//
//  dayfoldApp.swift
//  dayfold
//
//  Created by rich1e on 2026/4/7.
//

import SwiftUI

@main
struct dayfoldApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
