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
    @Environment(\.scenePhase) private var scenePhase

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
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // 仅在真正进入后台时记录时间戳。
                    // 注意：不要监听 `.inactive`，因为系统 Face ID 验证、控制中心、
                    // 通知中心等覆盖层都会短暂触发 .inactive，若此时记录时间，
                    // Face ID 验证通过后回到 .active 时会因 grace=0 误判为"超时"而重新锁屏。
                    securityManager.appDidEnterBackground()
                case .active:
                    securityManager.appWillEnterForeground()
                case .inactive:
                    // 故意忽略：见 background 分支注释。
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
