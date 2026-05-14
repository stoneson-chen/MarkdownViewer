import Foundation

/// User-configurable editor settings
struct EditorConfig: Codable {
    var fontSize: Double = 14
    var fontFamily: FontFamily = .sfMono
    var showLineNumbers: Bool = true
    var tabWidth: Int = 4
    var useSpacesForTabs: Bool = true
    var wordWrap: Bool = true
    var previewTheme: PreviewTheme = .github

    enum FontFamily: String, Codable, CaseIterable, Identifiable {
        case sfMono = "SF Mono"
        case menlo = "Menlo"
        case jetBrainsMono = "JetBrains Mono"
        case firaCode = "Fira Code"
        case courierNew = "Courier New"

        var id: String { rawValue }
    }

    enum PreviewTheme: String, Codable, CaseIterable, Identifiable {
        case github = "GitHub"
        case minimalist = "Minimalist"
        case academic = "Academic"

        var id: String { rawValue }
    }
}
