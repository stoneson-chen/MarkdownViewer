import SwiftUI

struct DocumentCommandActions {
    let isDirty: Bool
    let isEditing: Bool
    let openFile: () -> Void
    let saveFile: () -> Void
    let saveFileAs: () -> Void
    let toggleEditing: () -> Void
    let toggleSplitOrientation: () -> Void
    let formatBold: () -> Void
    let formatItalic: () -> Void
    let formatCode: () -> Void
    let formatH1: () -> Void
    let formatH2: () -> Void
    let formatH3: () -> Void
    let formatLink: () -> Void
    let formatImage: () -> Void
}

private struct DocumentCommandActionsKey: FocusedValueKey {
    typealias Value = DocumentCommandActions
}

extension FocusedValues {
    var documentCommandActions: DocumentCommandActions? {
        get { self[DocumentCommandActionsKey.self] }
        set { self[DocumentCommandActionsKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.documentCommandActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String(localized: "menu.open", bundle: .appResources)) {
                actions?.openFile()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(actions == nil)

            Divider()

            Button(String(localized: "menu.save", bundle: .appResources)) {
                actions?.saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(actions?.isDirty != true)

            Button(String(localized: "menu.saveAs", bundle: .appResources)) {
                actions?.saveFileAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(actions == nil)
        }

        CommandGroup(after: .toolbar) {
            Divider()

            let isEditing = actions?.isEditing == true
            let toggleLabel = isEditing
                ? String(localized: "menu.previewMode", bundle: .appResources)
                : String(localized: "menu.editMode", bundle: .appResources)
            Button(toggleLabel) {
                actions?.toggleEditing()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(actions == nil)

            if isEditing {
                Button(String(localized: "menu.toggleSplit", bundle: .appResources)) {
                    actions?.toggleSplitOrientation()
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
        }

        CommandMenu(String(localized: "menu.format", bundle: .appResources)) {
            Button(String(localized: "menu.bold", bundle: .appResources)) {
                actions?.formatBold()
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(actions?.isEditing != true)

            Button(String(localized: "menu.italic", bundle: .appResources)) {
                actions?.formatItalic()
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(actions?.isEditing != true)

            Button(String(localized: "menu.code", bundle: .appResources)) {
                actions?.formatCode()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(actions?.isEditing != true)

            Divider()

            Button(String(localized: "menu.h1", bundle: .appResources)) {
                actions?.formatH1()
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])
            .disabled(actions?.isEditing != true)

            Button(String(localized: "menu.h2", bundle: .appResources)) {
                actions?.formatH2()
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])
            .disabled(actions?.isEditing != true)

            Button(String(localized: "menu.h3", bundle: .appResources)) {
                actions?.formatH3()
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])
            .disabled(actions?.isEditing != true)

            Divider()

            Button(String(localized: "menu.link", bundle: .appResources)) {
                actions?.formatLink()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(actions?.isEditing != true)

            Button(String(localized: "menu.image", bundle: .appResources)) {
                actions?.formatImage()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(actions?.isEditing != true)
        }

        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "menu.about", bundle: .appResources)) {
                NSApp.sendAction(#selector(AppDelegate.showAboutWindow), to: nil, from: nil)
            }
        }
    }
}

extension AppDelegate {
    @MainActor @objc func showAboutWindow() {
        let aboutTitle = String(localized: "menu.about", bundle: .appResources)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "about" || $0.title == aboutTitle }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NotificationCenter.default.post(name: .showAboutWindow, object: nil)
        }
    }
}
