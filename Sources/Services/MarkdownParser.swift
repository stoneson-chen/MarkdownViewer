// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import Foundation

/// Parses Markdown text into HTML output for WKWebView preview.
/// Supports headings, code blocks, blockquotes, lists, tables, inline formatting, etc.
nonisolated final class MarkdownParser: Sendable {

    struct ParseResult: Sendable {
        let html: String
        let characterCount: Int
        let headings: [Heading]
    }

    struct Heading: Identifiable, Sendable {
        let level: Int
        let text: String
        let anchorID: String
        /// Stable identity for SwiftUI lists; matches the in-document anchor.
        var id: String { anchorID }
    }

    // MARK: - Pre-compiled Regexes (Shared & Thread-safe)

    private enum Regexes {
        static let heading = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$")
        static let thematicBreak = try! NSRegularExpression(pattern: "^(?:[\\s]*[-*_]){3,}[\\s]*$")
        static let taskList = try! NSRegularExpression(pattern: "^- \\[( |x)\\] (.+)$")
        static let unorderedList = try! NSRegularExpression(pattern: "^[-*+] (.+)$")
        static let orderedList = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+(.+)$")
        static let blockquote = try! NSRegularExpression(pattern: "^>[\\s]?(.*)$")

        // Inline
        static let image = try! NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)")
        static let link = try! NSRegularExpression(pattern: "(?<!\\!)\\[([^\\]]+)\\]\\(([^)]+)\\)")
        static let boldItalic = try! NSRegularExpression(pattern: "\\*\\*\\*(.+?)\\*\\*\\*")
        static let bold = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*|__(.+?)__")
        static let italic = try! NSRegularExpression(pattern: "\\*(.+?)\\*|(?<=\\s|^)_(.+?)_(?=\\s|$)")
        static let strikethrough = try! NSRegularExpression(pattern: "~~(.+?)~~")
        static let inlineCode = try! NSRegularExpression(pattern: "`([^`]+)`")

        /// Common HTML tags allowed in Markdown
        static let allowedTags: Set<String> = [
            "p", "br", "div", "span", "table", "thead", "tbody", "tr", "th", "td",
            "strong", "em", "b", "i", "u", "del", "ins", "hr",
            "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "img", "a"
        ]

        /// Regex to find potential escaped HTML tags for unescaping
        static let escapedTag = try! NSRegularExpression(pattern: "&lt;(/?)(\\w+)(.*?)&gt;")

        /// Attribute pairs in inline HTML (`key="value"`) for sanitization
        static let attributesKeyValue = try! NSRegularExpression(pattern: "(\\w+)\\s*=\\s*\"([^\"]*)\"")
    }

    // MARK: - Public API

    /// Full parse of the complete markdown text.
    func parse(_ markdown: String) -> ParseResult {
        let lines = markdown.components(separatedBy: .newlines)
        return parseLines(lines, fullText: markdown)
    }

    // MARK: - Nested List Rendering

    private func renderList(lines: [String], startIndex i: inout Int, indent: Int) -> String {
        var html = ""
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { break }
            
            let lineIndent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            if lineIndent < indent { break }
            
            if lineIndent > indent {
                // Should not happen at top level; skip
                i += 1; continue
            }
            
            let c = trimmed.first!
            var itemHTML = ""
            var nestedTag: String?
            
            if c == "-" || c == "*" || c == "+" {
                if let tm = Regexes.taskList.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    let checked = trimmed[Range(tm.range(at: 1), in: trimmed)!] == "x"
                    let text = processInline(String(trimmed[Range(tm.range(at: 2), in: trimmed)!]))
                    itemHTML = "<input type=\"checkbox\"\(checked ? " checked" : "") disabled> \(text)"
                    nestedTag = "ul"
                } else if let um = Regexes.unorderedList.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    itemHTML = processInline(String(trimmed[Range(um.range(at: 1), in: trimmed)!]))
                    nestedTag = "ul"
                } else { break }
            } else if c.isNumber {
                if let om = Regexes.orderedList.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    itemHTML = processInline(String(trimmed[Range(om.range(at: 2), in: trimmed)!]))
                    nestedTag = "ol"
                } else { break }
            } else { break }
            
            i += 1
            
            // Check for nested list on next line
            var nestedHTML = ""
            if i < lines.count {
                let nextLine = lines[i]
                let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                if !nextTrimmed.isEmpty {
                    let nextIndent = nextLine.prefix(while: { $0 == " " || $0 == "\t" }).count
                    let nextFirst = nextTrimmed.first!
                    let isNestedList = (nextFirst == "-" || nextFirst == "*" || nextFirst == "+"
                        || nextFirst.isNumber) && nextIndent > indent
                    if isNestedList {
                        nestedHTML = renderList(lines: lines, startIndex: &i, indent: nextIndent)
                    }
                }
            }
            
            // Build item HTML with optional nested list
            let cssClass = itemHTML.hasPrefix("<input") ? " class=\"task-list-item\"" : ""
            html += "<li\(cssClass)>"
            html += itemHTML
            if !nestedHTML.isEmpty {
                let tag = nestedTag ?? "ul"
                html += "\n<\(tag)>\n\(nestedHTML)</\(tag)>\n"
            }
            html += "</li>\n"
        }
        
        return html
    }

    // MARK: - Core Parse Engine

    private func parseLines(_ lines: [String], fullText: String) -> ParseResult {
        var htmlParts: [String] = []
        htmlParts.reserveCapacity(lines.count * 2)

        var headings: [Heading] = []
        var slugCounts: [String: Int] = [:]
        var i = 0
        var inParagraph = false

        // Front Matter detection: --- ... --- at very start of file
        if !lines.isEmpty && lines[0].trimmingCharacters(in: .whitespaces) == "---" {
            var fmLines: [String] = []
            i = 1
            while i < lines.count {
                if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                    i += 1; break
                }
                fmLines.append(lines[i])
                i += 1
            }
            if !fmLines.isEmpty {
                let fmContent = fmLines.joined(separator: "\n")
                htmlParts.append("""
                <details style='margin-bottom:1.2em;font-size:0.9em'>
                <summary style='cursor:pointer;color:var(--text-secondary);user-select:none'>\(String.appLocalized("parser.metadata.summary"))</summary>
                <pre style='margin-top:0.5em;padding:12px 16px;background:var(--bg-code);border-radius:6px;font-size:0.85em;line-height:1.5;overflow-x:auto'>\(escapeHTML(fmContent))</pre>
                </details>
                """)
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            guard !trimmed.isEmpty else {
                if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                i += 1; continue
            }

            // Fast dispatch by first character to minimize regex checks
            switch trimmed.first {
            case "#":
                if let hMatch = Regexes.heading.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                    let levelRange = Range(hMatch.range(at: 1), in: trimmed)!
                    let level = trimmed[levelRange].count
                    let textRange = Range(hMatch.range(at: 2), in: trimmed)!
                    let text = String(trimmed[textRange])
                    let anchorID = generateUniqueSlug(text, counts: &slugCounts)
                    headings.append(Heading(level: level, text: text, anchorID: anchorID))
                    htmlParts.append("<h\(level) id=\"\(anchorID)\">\(processInline(text))</h\(level)>\n")
                    i += 1; continue
                }
                // Not a heading — fall through to paragraph
                break

            case "`":
                if trimmed.hasPrefix("```") {
                    if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    var codeLines: [String] = []
                    i += 1
                    while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        codeLines.append(lines[i])
                        i += 1
                    }
                    i += 1
                    htmlParts.append("<pre><code class=\"language-\(escapeHTML(lang))\">\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>\n")
                    continue
                }
                break

            case ">":
                if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                var quoteLines: [(level: Int, content: String)] = []
                while i < lines.count {
                    let ql = lines[i]
                    let qt = ql.trimmingCharacters(in: .whitespaces)
                    let qLevel = qt.prefix(while: { $0 == ">" }).count
                    if qLevel == 0 { break }
                    let startIdx = qt.index(qt.startIndex, offsetBy: qLevel)
                    var content = String(qt[startIdx...])
                    if content.first == " " { content.removeFirst() }
                    quoteLines.append((level: qLevel, content: content))
                    i += 1
                }
                // Build nested blockquotes with proper level handling
                htmlParts.append(renderNestedBlockquote(quoteLines))
                continue

            case "-", "*", "+":
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                // `+` is never a thematic break, so only check it for `-`/`*`.
                if trimmed.first != "+",
                   Regexes.thematicBreak.firstMatch(in: trimmed, range: range) != nil {
                    if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                    htmlParts.append("<hr>\n")
                    i += 1; continue
                }
                if Regexes.taskList.firstMatch(in: trimmed, range: range) != nil
                    || Regexes.unorderedList.firstMatch(in: trimmed, range: range) != nil {
                    if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                    htmlParts.append("<ul>\n")
                    let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                    htmlParts.append(renderList(lines: lines, startIndex: &i, indent: indent))
                    htmlParts.append("</ul>\n")
                    continue
                }
                break

            case let c? where c.isNumber:
                if let om = Regexes.orderedList.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                    let startNum = String(trimmed[Range(om.range(at: 1), in: trimmed)!])
                    htmlParts.append("<ol start=\"\(startNum)\">\n")
                    let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                    htmlParts.append(renderList(lines: lines, startIndex: &i, indent: indent))
                    htmlParts.append("</ol>\n")
                    continue
                }
                break

            case "|":
                // Table detection: need | in current AND next line
                if i + 1 < lines.count {
                    let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.contains("|") && nextTrimmed.contains("-") {
                        if inParagraph { htmlParts.append("</p>\n"); inParagraph = false }
                        htmlParts.append(renderTable(lines: lines, startIndex: &i))
                        continue
                    }
                }
                break

            default:
                break
            }

            // Paragraph (default case)
            if !inParagraph {
                htmlParts.append("<p>")
                inParagraph = true
            } else {
                htmlParts.append("<br>")
            }
            htmlParts.append(processInline(line))
            i += 1
        }

        if inParagraph { htmlParts.append("</p>\n") }

        return ParseResult(
            html: htmlParts.joined(),
            characterCount: fullText.count,
            headings: headings
        )
    }

    // MARK: - Inline Processing

    private func processInline(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        // Fast path: no markdown triggers at all
        if !text.contains(where: { "![]*_~`<&\"\\".contains($0) }) {
            return text
        }

        var result = escapeHTML(text)
        let codeTokens = protectInlineCode(in: &result)

        // 1. Unescape allowed HTML tags with strict attribute filtering
        if result.contains("&lt;") {
            let matches = Regexes.escapedTag.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                guard let tagRange = Range(match.range(at: 2), in: result) else { continue }
                let tagName = String(result[tagRange]).lowercased()
                if Regexes.allowedTags.contains(tagName) {
                    let fullMatchRange = Range(match.range, in: result)!
                    let slash = match.range(at: 1).length > 0 ? "/" : ""
                    
                    // XSS Fix: Only allow safe attributes and values
                    let rawAttrs = String(result[Range(match.range(at: 3), in: result)!])
                        .replacingOccurrences(of: "&quot;", with: "\"")
                    let safeAttrs = sanitizeAttributes(rawAttrs)
                    
                    result.replaceSubrange(fullMatchRange, with: "<\(slash)\(tagName)\(safeAttrs)>")
                }
            }
        }

        // 2. Images (before links so ![alt](url) isn't confused with [text](url))
        if result.contains("![") {
            let matches = Regexes.image.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                if let altRange = Range(match.range(at: 1), in: result),
                   let urlRange = Range(match.range(at: 2), in: result) {
                    let alt = String(result[altRange])
                    let url = smartEncodeURL(String(result[urlRange]))
                    result.replaceSubrange(Range(match.range, in: result)!, with: "<img src=\"\(url)\" alt=\"\(alt)\">")
                }
            }
        }

        // 3. Links
        if result.contains("[") {
            let matches = Regexes.link.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: result),
                   let urlRange = Range(match.range(at: 2), in: result) {
                    let text = String(result[textRange])
                    let url = smartEncodeURL(String(result[urlRange]))
                    result.replaceSubrange(Range(match.range, in: result)!, with: "<a href=\"\(url)\" target=\"_blank\" rel=\"noopener\">\(text)</a>")
                }
            }
        }

        // 4. Bold/Italic/Strikethrough
        if result.contains("*") || result.contains("_") {
            result = Regexes.boldItalic.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<strong><em>$1</em></strong>")
            result = Regexes.bold.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<strong>$1$2</strong>")
            result = Regexes.italic.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<em>$1$2</em>")
        }

        if result.contains("~") {
            result = Regexes.strikethrough.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<del>$1</del>")
        }

        for token in codeTokens {
            result = result.replacingOccurrences(of: token.placeholder, with: token.html)
        }

        return result
    }

    private func protectInlineCode(in result: inout String) -> [(placeholder: String, html: String)] {
        guard result.contains("`") else { return [] }

        var tokens: [(placeholder: String, html: String)] = []
        let matches = Regexes.inlineCode.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let codeRange = Range(match.range(at: 1), in: result) else { continue }

            let placeholder = "MDINLINECODETOKEN\(tokens.count)END"
            let code = String(result[codeRange])
            tokens.append((placeholder, "<code>\(code)</code>"))
            result.replaceSubrange(fullRange, with: placeholder)
        }
        return tokens
    }

    private func smartEncodeURL(_ urlString: String) -> String {
        // Block dangerous protocols
        let lower = urlString.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.hasPrefix("javascript:") || lower.hasPrefix("data:text/html") || lower.hasPrefix("vbscript:") {
            return "#"
        }
        if urlString.contains("%") { return urlString }
        if urlString.starts(with: "http") {
            return urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        }
        return urlString.components(separatedBy: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0
        }.joined(separator: "/")
    }

    private func escapeHTML(_ text: String) -> String {
        if !text.contains(where: { "&<>\"".contains($0) }) {
            return text
        }
        var escaped = ""
        escaped.reserveCapacity(text.count + 20)
        for char in text {
            switch char {
            case "&": escaped.append("&amp;")
            case "<": escaped.append("&lt;")
            case ">": escaped.append("&gt;")
            case "\"": escaped.append("&quot;")
            default: escaped.append(char)
            }
        }
        return escaped
    }

    // MARK: - Table Rendering

    private func renderTable(lines: [String], startIndex i: inout Int) -> String {
        var tableHtml = "<table>\n<thead><tr>\n"
        for cell in parseTableRow(lines[i]) {
            tableHtml += "<th>\(processInline(cell))</th>\n"
        }
        tableHtml += "</tr></thead>\n<tbody>\n"
        i += 2
        while i < lines.count {
            let row = lines[i].trimmingCharacters(in: .whitespaces)
            guard row.contains("|") && !row.isEmpty else { break }
            tableHtml += "<tr>\n"
            for cell in parseTableRow(lines[i]) {
                tableHtml += "<td>\(processInline(cell))</td>\n"
            }
            tableHtml += "</tr>\n"
            i += 1
        }
        tableHtml += "</tbody>\n</table>\n"
        return tableHtml
    }

    private func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
        let final = stripped.hasSuffix("|") ? String(stripped.dropLast()) : stripped
        return final.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Helpers

    private func sanitizeAttributes(_ raw: String) -> String {
        let safeList = ["src", "href", "alt", "title", "class", "id", "width", "height", "style"]
        var sanitized = ""
        
        let matches = Regexes.attributesKeyValue.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
        
        for m in matches {
            guard let keyRange = Range(m.range(at: 1), in: raw),
                  let valRange = Range(m.range(at: 2), in: raw) else { continue }
            
            let key = String(raw[keyRange]).lowercased()
            var val = String(raw[valRange])
            
            if safeList.contains(key) {
                // Protocol filtering for URLs
                if (key == "href" || key == "src") && val.lowercased().contains("javascript:") {
                    val = "#"
                }
                sanitized += " \(key)=\"\(val)\""
            }
        }
        return sanitized
    }

    private func generateUniqueSlug(_ text: String, counts: inout [String: Int]) -> String {
        let base = text.lowercased().compactMap { char -> String? in
            if char.isLetter || char.isNumber { return String(char) }
            if char.isWhitespace { return "-" }
            return nil
        }.joined()
        let slug = base.isEmpty ? "heading" : base.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        let count = counts[slug, default: 0]
        counts[slug] = count + 1
        
        if count == 0 {
            return slug
        } else {
            return "\(slug)-\(count)"
        }
    }

    // MARK: - Blockquote Rendering

    private func renderNestedBlockquote(_ lines: [(level: Int, content: String)]) -> String {
        guard !lines.isEmpty else { return "" }
        var html = "<blockquote>"
        for line in lines {
            if line.level > 1 {
                // Add extra nesting for each additional >
                for _ in 1..<line.level { html += "<blockquote>" }
                html += "<p>\(processInline(line.content))</p>"
                for _ in 1..<line.level { html += "</blockquote>" }
            } else {
                html += "<p>\(processInline(line.content))</p>"
            }
        }
        html += "</blockquote>\n"
        return html
    }
}

extension NSRegularExpression {
    func stringByReplacingMatches(in string: String, range: NSRange, withTemplate template: String) -> String {
        return self.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: template)
    }
}
