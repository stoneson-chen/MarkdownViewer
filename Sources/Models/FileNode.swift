import Foundation

/// Represents a node in the file tree sidebar
struct FileNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode]?

    /// Icon name based on file type
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        return "doc.text.fill"
    }

    /// Whether this node represents a Markdown file
    var isMarkdown: Bool {
        guard !isDirectory else { return false }
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "md", "markdown", "mdown":
            return true
        default:
            return false
        }
    }
}
