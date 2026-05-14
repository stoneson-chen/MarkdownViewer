import Foundation

final class WindowCommandScope: NSObject {}

extension Notification.Name {
    // MARK: - Editor Formatting
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatCode = Notification.Name("formatCode")
    static let formatH1 = Notification.Name("formatH1")
    static let formatH2 = Notification.Name("formatH2")
    static let formatH3 = Notification.Name("formatH3")
    static let formatLink = Notification.Name("formatLink")
    static let formatImage = Notification.Name("formatImage")

    // MARK: - View Control
    static let openFilePanel = Notification.Name("openFilePanel")
    static let saveFile = Notification.Name("saveFile")
    static let saveFileAs = Notification.Name("saveFileAs")
    static let toggleEditing = Notification.Name("toggleEditing")
    static let toggleSplitOrientation = Notification.Name("toggleSplitOrientation")
    static let showAboutWindow = Notification.Name("showAboutWindow")

    // MARK: - Navigation & Sync
    static let openFileURL = Notification.Name("openFileURL")
    static let scrollToHeading = Notification.Name("scrollToHeading")
    static let didDetectHeading = Notification.Name("didDetectHeading")
    static let executeScrollJS = Notification.Name("executeScrollJS")
    static let editorDidScroll = Notification.Name("editorDidScroll")
    static let previewDidScroll = Notification.Name("previewDidScroll")
}
