// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import AppKit
import Foundation
import UniformTypeIdentifiers

struct DocumentExportOptions {
    let format: String
    let margin: Double
    let includeTOC: Bool
    let applyCSS: Bool
}

enum DocumentExportService {
    static func docxContentType() -> UTType? {
        if let type = UTType(filenameExtension: "docx") {
            return type
        }
        return UTType("org.openxmlformats.wordprocessingml.document")
    }

    @MainActor
    static func exportDocx(
        viewModel: DocumentViewModel,
        to url: URL,
        options: DocumentExportOptions
    ) throws {
        let themeVars = switch UserDefaults.standard.string(forKey: "previewTheme") ?? "light" {
        case "dark": PreviewThemes.darkVars
        case "sepia": PreviewThemes.sepiaVars
        case "ocean": PreviewThemes.oceanVars
        default: PreviewThemes.lightVars
        }

        let fontFamily = UserDefaults.standard.string(forKey: "editorFontFamily") ?? "SF Pro"
        let fontSize = UserDefaults.standard.double(forKey: "editorFontSize")
        let editorFontSize = fontSize > 0 ? fontSize : 15.0
        let editorLineHeight = UserDefaults.standard.double(forKey: "editorLineHeight") > 0
            ? UserDefaults.standard.double(forKey: "editorLineHeight") : 1.6

        let fontFamilyCSS = switch fontFamily {
        case "SF Mono": "ui-monospace, monospace"
        case "New York": "Georgia, serif"
        default: "system-ui, -apple-system, sans-serif"
        }

        var rules = themeVars.map { "\($0.key): \($0.value);" }.joined(separator: " ")
        rules += " --font-family-base: \(fontFamilyCSS);"
        rules += " --font-size-base: \(editorFontSize)px;"
        rules += " --line-height-base: \(editorLineHeight);"

        let cssString = options.applyCSS ? viewModel.previewCSS : ""
        let tocTitle = String(localized: "outline.title", bundle: .appResources)
        let tocHTML = options.includeTOC
            ? WebPreview.buildExportTOCHTML(
                headings: viewModel.headings,
                fallbackHTML: viewModel.renderedHTML,
                tocTitle: tocTitle
            )
            : ""
        let tocSection = tocHTML.isEmpty ? "" : "<nav class=\"export-toc\">\(tocHTML)</nav>"

        let exportHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
            :root { \(rules) }
            body {
                font-family: var(--font-family-base) !important;
                font-size: var(--font-size-base) !important;
                line-height: var(--line-height-base) !important;
                color: var(--text-primary) !important;
                background-color: var(--bg-primary) !important;
                padding: 2em;
                max-width: 800px;
                margin: 0 auto;
            }
            .export-toc {
                margin-bottom: 2em;
                page-break-after: always;
            }
            .export-toc ul {
                list-style: none;
                padding-left: 0;
                margin: 0;
            }
            .export-toc li {
                line-height: 1.6;
            }
            .export-toc a {
                color: inherit;
                text-decoration: none;
            }
            blockquote {
                border-left: 3px solid #d2d2d7 !important;
                margin-left: 12pt !important;
                padding-left: 10pt !important;
                color: #6e6e73 !important;
                mso-border-left-alt: 3.0pt solid #d2d2d7 !important;
            }
            table {
                border-collapse: collapse !important;
                mso-table-lspace: 2.25pt !important;
                mso-table-rspace: 2.25pt !important;
            }
            th, td {
                border: 1px solid #d2d2d7 !important;
                padding: 6pt !important;
            }
            \(cssString)
            </style>
        </head>
        <body>
            <article class="markdown-body">
            \(tocSection)
            \(viewModel.renderedHTML)
            </article>
        </body>
        </html>
        """

        guard let htmlData = exportHTML.data(using: .utf8) else {
            throw ExportError.invalidHTML
        }

        let parseOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attrStr = try NSAttributedString(data: htmlData, options: parseOptions, documentAttributes: nil)
        let docxData = try attrStr.data(
            from: NSRange(location: 0, length: attrStr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        try docxData.write(to: url)
    }

    enum ExportError: LocalizedError {
        case invalidHTML
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidHTML:
                return String(localized: "export.failed", bundle: .appResources)
            case .unsupportedFormat:
                return String(localized: "export.failed", bundle: .appResources)
            }
        }
    }
}
