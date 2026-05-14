import SwiftUI
import UniformTypeIdentifiers

/// UTType extension for Markdown file identification.
/// Used by file association and open/save panels.
extension UTType {
    /// Ensure .markdown UTType is available
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    }
}
