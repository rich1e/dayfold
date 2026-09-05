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
    @State private var themeManager = ThemeManager.shared

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
                        .environmentObject(coreDataStack)
                }
            }
            // 注入主题（EnvironmentKey 协议值通过 .environment(\.theme, ...) 传递）
            .environment(\.theme, themeManager.current)
            // colorScheme 跟随当前主题：暖色暗调/纯黑 → dark，暖色亮调 → light
            .preferredColorScheme(themeManager.id.colorScheme)
            .onAppear {
                coreDataStack.createPresetTags()
                coreDataStack.ensureDefaultNotebook()
            }
        }
    }
}
