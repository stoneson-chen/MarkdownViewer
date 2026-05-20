// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some Scene {
        WindowGroup(id: "document") {
            windowContent()
        }
        .commands {
            AppCommands()
        }
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
        }

        Window(String(localized: "menu.about", bundle: .appResources), id: "about") {
            AboutView()
                .preferredColorScheme(appTheme.colorScheme)
                .onAppear { applyAppAppearance(appTheme) }
                .onChange(of: appTheme) { _, theme in applyAppAppearance(theme) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    private func windowContent() -> some View {
        ContentView()
            .frame(minWidth: 600, minHeight: 400)
            .preferredColorScheme(appTheme.colorScheme)
            .onAppear {
                applyAppAppearance(appTheme)
                AppDelegate.requestDocumentWindow = {
                    openWindow(id: "document")
                }
            }
            .onChange(of: appTheme) { _, theme in
                applyAppAppearance(theme)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAboutWindow)) { _ in
                openWindow(id: "about")
            }
    }

    /// `preferredColorScheme(nil)` alone does not always restore Aqua when leaving forced dark; sync AppKit appearance.
    private func applyAppAppearance(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - AppDelegate for file association & lifecycle

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct WindowRegistration {
        let scope: WindowCommandScope
        let canReuse: () -> Bool
        let openURL: (URL) -> Void
    }

    @MainActor private static var queuedOpenURLs: [URL] = []
    @MainActor private static var windowRegistrations: [WindowRegistration] = []
    @MainActor static var requestDocumentWindow: (() -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(Self.routeOpenURL)
    }

    private static func routeOpenURL(_ url: URL) {
        if openInReusableWindow(url) {
            return
        }
        queuedOpenURLs.append(url)
        requestDocumentWindow?()
    }

    static func consumeQueuedOpenURL() -> URL? {
        guard !queuedOpenURLs.isEmpty else { return nil }
        return queuedOpenURLs.removeFirst()
    }

    static func registerWindow(
        scope: WindowCommandScope,
        canReuse: @escaping () -> Bool,
        openURL: @escaping (URL) -> Void
    ) {
        unregisterWindow(scope: scope)
        windowRegistrations.append(WindowRegistration(scope: scope, canReuse: canReuse, openURL: openURL))
    }

    static func unregisterWindow(scope: WindowCommandScope) {
        windowRegistrations.removeAll { $0.scope === scope }
    }

    static func openInReusableWindow(_ url: URL) -> Bool {
        guard let registration = windowRegistrations.last(where: { $0.canReuse() }) else {
            return false
        }
        registration.openURL(url)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
