// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

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
