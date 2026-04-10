//
//  dayfoldApp.swift
//  dayfold
//
//  Created by rich1e on 2026/4/7.
//

import SwiftUI

@main
struct dayfoldApp: App {
    @StateObject private var coreDataStack = CoreDataStack.shared
    @StateObject private var securityManager = SecurityManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if securityManager.isLocked {
                    LockScreenView()
                        .environmentObject(securityManager)
                } else {
                    MainTabView()
                        .environment(\.managedObjectContext, coreDataStack.viewContext)
                        .environmentObject(securityManager)
                }
            }
            .onAppear {
                coreDataStack.createPresetTags()
            }
        }
    }
}
