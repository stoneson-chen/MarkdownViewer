// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Core ViewModel managing file state, editing mode, and preview rendering.
@Observable
@MainActor
final class DocumentViewModel {
    // MARK: - Content State

    /// The markdown source text
    var text: String = ""

    /// Rendered HTML for the WKWebView preview
    private(set) var renderedHTML: String = ""
    private(set) var previewCSS: String = ""
    private(set) var characterCount: Int = 0
    private(set) var headings: [MarkdownParser.Heading] = []
    private(set) var isRendering = false

    /// 当前正在阅读的标题 ID（用于侧边栏高亮）
    var activeHeadingID: String?

    // MARK: - Search State

    /// Whether the search overlay is presented
    var isSearchPresented: Bool = false {
        didSet {
            if !isSearchPresented {
                searchQuery = ""
            }
        }
    }

    /// Current active search term
    var searchQuery: String = "" {
        didSet {
            currentSearchMatchIndex = 0
            NotificationCenter.default.post(
                name: .didUpdateSearchQuery,
                object: self,
                userInfo: ["query": searchQuery]
            )
        }
    }

    /// 0-based index of the currently highlighted match
    var currentSearchMatchIndex: Int = 0

    /// Total count of keyword matches found
    var totalSearchMatchesCount: Int = 0

    /// Jump to the next match
    func searchNext() {
        guard totalSearchMatchesCount > 0 else { return }
        currentSearchMatchIndex = (currentSearchMatchIndex + 1) % totalSearchMatchesCount
        NotificationCenter.default.post(
            name: .didNavigateSearchMatch,
            object: self,
            userInfo: ["index": currentSearchMatchIndex]
        )
    }

    /// Jump to the previous match
    func searchPrev() {
        guard totalSearchMatchesCount > 0 else { return }
        currentSearchMatchIndex = (currentSearchMatchIndex - 1 + totalSearchMatchesCount) % totalSearchMatchesCount
        NotificationCenter.default.post(
            name: .didNavigateSearchMatch,
            object: self,
            userInfo: ["index": currentSearchMatchIndex]
        )
    }

    /// Invoked when the web page reports the match count
    func updateSearchMatchesCount(_ count: Int) {
        totalSearchMatchesCount = count
        if totalSearchMatchesCount > 0 && currentSearchMatchIndex >= totalSearchMatchesCount {
            currentSearchMatchIndex = totalSearchMatchesCount - 1
        }
    }

    // MARK: - File State

    /// Currently opened file URL; nil when showing default README
    var fileURL: URL? {
        didSet {
            updateWindowTitle()
            _cachedCSS = nil
            _cachedBaseURL = nil
            Task { await refreshCSS() }
        }
    }

    /// Whether the document has unsaved changes
    private(set) var isDirty = false

    /// Error message for user-facing alerts; nil when no error
    var errorMessage: String?

    // MARK: - View State

    /// false = preview-only (default); true = dual-pane editing
    var isEditing: Bool = false

    /// Split direction in editing mode
    var splitOrientation: SplitOrientation = .horizontal

    /// Custom CSS file URL for preview styling (from Settings)
    @ObservationIgnored
    @AppStorage("userCustomCSSPath") var customCSSPath: String = "" {
        didSet {
            _cachedCSS = nil
            Task { await refreshCSS() }
        }
    }

    /// Window title
    private(set) var windowTitle: String = "README.md"

    /// Title shown in the window chrome; appends * when there are unsaved changes.
    var displayedWindowTitle: String {
        isDirty ? "\(windowTitle)*" : windowTitle
    }

    var canReuseForExternalOpen: Bool {
        fileURL == nil && !isDirty
    }

    // MARK: - Types

    enum SplitOrientation: String, CaseIterable, Identifiable {
        case horizontal = "horizontal"
        case vertical = "vertical"

        var displayName: String {
            switch self {
            case .horizontal: return String(localized: "split.horizontal", bundle: .appResources)
            case .vertical: return String(localized: "split.vertical", bundle: .appResources)
            }
        }
        
        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .horizontal: return "rectangle.split.2x1"
            case .vertical: return "rectangle.split.1x2"
            }
        }
    }

    // MARK: - Private

    private let parser = MarkdownParser()
    private var debounceTask: Task<Void, Never>?
    private var pendingOpenURL: URL?
    private var _cachedCSS: String?
    private var _cachedBaseURL: URL?
    private var originalText: String = ""
    private var parseRevision = 0
    /// Bumps on each `openFile` so stale async loads cannot overwrite the current document.
    private var openGeneration = 0

    // MARK: - Lifecycle

    /// Load default content on init. Called once.
    func loadInitialContent() async {
        // If a file was already opened, don't overwrite it.
        if fileURL != nil { return }

        if let url = Self.lastQueuedOpenURL() {
            openFile(url)
            return
        }

        // Check command line arguments for a file path
        let args = CommandLine.arguments
        if args.count > 1 {
            let path = args[1]
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                openFile(url)
                return
            }
        }

        // Give Launch Services a short window to deliver file-open events before falling back.
        try? await Task.sleep(for: .milliseconds(250))
        guard fileURL == nil else { return }

        if let url = Self.lastQueuedOpenURL() {
            openFile(url)
            return
        }

        // Only use README as filler when no external URL/file input exists.
        loadDefaultReadme()
    }

    // MARK: - File Operations

    /// Load the bundled README.md
    func loadDefaultReadme() {
        if let url = Bundle.appResources.url(forResource: "README", withExtension: "md"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            text = content
        } else {
            text = String.appLocalized("fallback.readme")
        }
        fileURL = nil
        originalText = text
        isDirty = false
        isRendering = true
        parseRevision += 1
        Task { await parseProgressive() }
    }

    /// Open a file from URL
    func openFile(_ url: URL) {
        let target = url.standardized
        if fileURL?.standardized == target { return }
        if pendingOpenURL == target { return }

        debounceTask?.cancel()
        parseRevision += 1
        openGeneration += 1
        let generation = openGeneration
        pendingOpenURL = target

        Task {
            do {
                defer {
                    if pendingOpenURL == target { pendingOpenURL = nil }
                }

                let content = try await Task.detached(priority: .userInitiated) {
                    try String(contentsOf: target, encoding: .utf8)
                }.value

                guard generation == openGeneration else { return }

                self.text = content
                self.fileURL = target
                self.originalText = content
                self.isDirty = false
                self.isRendering = true
                self.characterCount = content.count

                let revision = nextParseRevision()
                await runAsyncParse(content, revision: revision)
            } catch {
                guard generation == openGeneration else { return }
                isRendering = false
                errorMessage = String(localized: "error.open", bundle: .appResources) + ": " + error.localizedDescription
            }
        }
    }

    /// Show open panel and open selected file
    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.markdown]
        panel.message = String(localized: "dialog.openFile", bundle: .appResources)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFile(url)
    }

    /// Save current content to file
    func saveFile() {
        guard let url = fileURL else {
            saveFileAs()
            return
        }

        let snapshot = text
        Task {
            do {
                try await Self.writeText(snapshot, to: url)
                originalText = snapshot
                isDirty = (text != snapshot)
            } catch {
                errorMessage = String(localized: "error.save", bundle: .appResources) + error.localizedDescription
            }
        }
    }

    /// Save As: prompt for new location
    func saveFileAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdown]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let snapshot = text
        Task {
            do {
                try await Self.writeText(snapshot, to: url)
                fileURL = url
                originalText = snapshot
                isDirty = (text != snapshot)
                let revision = nextParseRevision()
                isRendering = true
                await runAsyncParse(text, revision: revision)
            } catch {
                errorMessage = String(localized: "error.saveAs", bundle: .appResources) + error.localizedDescription
            }
        }
    }

    // MARK: - Text Change Handling

    /// Called when the editor text changes. Debounces by 80ms before a full parse.
    func textDidChange(_ newText: String) {
        text = newText
        isDirty = (text != originalText)

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            let revision = nextParseRevision()
            isRendering = true
            await runAsyncParse(text, revision: revision)
        }
    }

    /// Single async parse path. Parsing **and** image base64 inlining run off-main to keep typing/scrolling smooth.
    private func parseProgressive() async {
        characterCount = text.count
        isRendering = true
        let revision = nextParseRevision()
        await runAsyncParse(text, revision: revision)
    }

    private func runAsyncParse(_ markdown: String, revision: Int) async {
        let parser = self.parser
        let directory = fileURL?.deletingLastPathComponent()
        let (html, characters, headings) = await Task.detached(priority: .userInitiated) {
            let result = parser.parse(markdown)
            let embedded = Self.resolveLocalImageSources(in: result.html, relativeTo: directory)
            return (embedded, result.characterCount, result.headings)
        }.value

        guard revision == parseRevision else { return }
        renderedHTML = html
        characterCount = characters
        self.headings = headings
        isRendering = false
    }
    // MARK: - View Toggles

    func toggleEditing() {
        withAnimation(.spring(duration: 0.3)) {
            isEditing.toggle()
        }
    }

    func toggleSplitOrientation() {
        withAnimation(.spring(duration: 0.3)) {
            splitOrientation = (splitOrientation == .horizontal) ? .vertical : .horizontal
        }
    }

    // MARK: - Navigation

    /// Request a scroll to a specific heading in the preview.
    func scrollToHeading(_ heading: MarkdownParser.Heading, scope: WindowCommandScope) {
        NotificationCenter.default.post(
            name: .executeScrollJS,
            object: scope,
            userInfo: ["anchorID": heading.anchorID]
        )
    }

    // MARK: - CSS Resolution

    /// Resolve the CSS to use for preview: per-file CSS → settings CSS → default
    private func refreshCSS() async {
        if let cached = _cachedCSS {
            previewCSS = cached
            return
        }

        let fileURL = self.fileURL
        let customCSSPath = self.customCSSPath
        let css = await Task.detached(priority: .utility) {
            Self.loadCSS(fileURL: fileURL, customCSSPath: customCSSPath)
        }.value

        guard self.fileURL == fileURL, self.customCSSPath == customCSSPath else { return }
        if !css.isEmpty {
            _cachedCSS = css
        }
        previewCSS = css
    }

    nonisolated private static func loadCSS(fileURL: URL?, customCSSPath: String) -> String {
        // 1. Per-file CSS (same basename, .css extension, same directory)
        if let fileURL = fileURL {
            let cssURL = fileURL.deletingPathExtension().appendingPathExtension("css")
            if let perFileCSS = try? String(contentsOf: cssURL, encoding: .utf8) {
                return perFileCSS
            }
        }
        // 2. User-configured custom CSS path
        if !customCSSPath.isEmpty,
           let userCSS = try? String(contentsOf: URL(fileURLWithPath: customCSSPath), encoding: .utf8) {
            return userCSS
        }
        // 3. Bundled default
        if let url = Bundle.appResources.url(forResource: "default", withExtension: "css"),
           let defaultCSS = try? String(contentsOf: url, encoding: .utf8) {
            return defaultCSS
        }
        // Don't cache empty CSS — allows retry on next call
        return ""
    }

    // MARK: - Base URL Resolution for Preview

    /// `file://` directory of the open document, used as WKWebView `baseURL`. `nil` for the default README.
    func resolveRenderingBase() -> URL? {
        if let cached = _cachedBaseURL { return cached }
        guard let fileURL else { return nil }
        let base = fileURL.deletingLastPathComponent().standardized
        _cachedBaseURL = base
        return base
    }

    // MARK: - Private Helpers

    private func updateWindowTitle() {
        if let url = fileURL {
            windowTitle = url.lastPathComponent
        } else {
            windowTitle = "README.md"
        }
    }

    private func nextParseRevision() -> Int {
        parseRevision += 1
        return parseRevision
    }

    nonisolated private static func writeText(_ text: String, to url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }.value
    }

    // MARK: - Local Image Inlining

    /// Rewrites relative `<img src>` to data URLs, with a per-URL (mtime, dataURL) cache.
    /// Runs off-main from `runAsyncParse`.
    nonisolated static func resolveLocalImageSources(in html: String, relativeTo directory: URL?) -> String {
        guard let directory, html.contains("<img") else { return html }

        let nsHTML = html as NSString
        let matches = Self.imgSrcRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        guard !matches.isEmpty else { return html }

        let mutable = NSMutableString(string: html)
        for match in matches.reversed() where match.numberOfRanges > 2 {
            let srcRange = match.range(at: 2)
            let src = nsHTML.substring(with: srcRange)
            guard let absolute = absoluteFileURL(forAssetPath: src, relativeTo: directory),
                  let dataURL = cachedDataURL(for: absolute) else { continue }

            let escaped = dataURL
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            mutable.replaceCharacters(in: srcRange, with: escaped)
        }
        return mutable as String
    }

    // Pattern is fixed and well-tested; force-try to surface programmer errors at startup.
    nonisolated private static let imgSrcRegex: NSRegularExpression =
        try! NSRegularExpression(pattern: #"<img\s+([^>]*?\s+)?src="([^"]+)"([^>]*)>"#, options: .caseInsensitive)

    /// Memoize base64 data URLs keyed by `(absolute path, modification date)`.
    /// Re-parses on edit only redo the work for assets that actually changed.
    nonisolated private struct AssetCacheEntry {
        let mtime: Date
        let dataURL: String
        let byteCount: Int
        let lastAccess: Int
    }

    nonisolated(unsafe) private static var assetCache: [URL: AssetCacheEntry] = [:]
    nonisolated(unsafe) private static var assetCacheBytes = 0
    nonisolated(unsafe) private static var assetCacheTick = 0
    nonisolated private static let assetCacheLock = NSLock()
    nonisolated private static let maxAssetCacheBytes = 32_000_000
    nonisolated private static let maxAssetCacheEntries = 64

    nonisolated private static func cachedDataURL(for fileURL: URL) -> String? {
        let mtime = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date)
            ?? .distantPast

        assetCacheLock.lock()
        assetCacheTick += 1
        let accessTick = assetCacheTick
        let cached = assetCache[fileURL]
        if let cached, cached.mtime == mtime {
            assetCache[fileURL] = AssetCacheEntry(
                mtime: cached.mtime,
                dataURL: cached.dataURL,
                byteCount: cached.byteCount,
                lastAccess: accessTick
            )
            assetCacheLock.unlock()
            return cached.dataURL
        }
        if let cached {
            assetCacheBytes -= cached.byteCount
            assetCache[fileURL] = nil
        }
        assetCacheLock.unlock()

        switch loadAssetData(at: fileURL) {
        case .success(let data):
            let mime = mimeType(forPreviewAsset: fileURL.pathExtension)
            let dataURL = "data:\(mime);base64,\(data.base64EncodedString())"
            let byteCount = dataURL.utf8.count
            assetCacheLock.lock()
            assetCache[fileURL] = AssetCacheEntry(
                mtime: mtime,
                dataURL: dataURL,
                byteCount: byteCount,
                lastAccess: accessTick
            )
            assetCacheBytes += byteCount
            pruneAssetCacheIfNeeded()
            assetCacheLock.unlock()
            return dataURL
        case .failure(let error):
            NSLog("[MarkdownViewer] failed to inline image '%@': %@", fileURL.path, error.localizedDescription)
            let message: String
            if error.localizedDescription.localizedCaseInsensitiveContains("exceeds") || error.localizedDescription.localizedCaseInsensitiveContains("8 MB") {
                message = "Asset Exceeds 8MB Limit"
            } else {
                message = "Asset Load Failed"
            }
            let escapedFilename = xmlEscape(fileURL.lastPathComponent)
            let escapedMessage = xmlEscape(message)
            return generateFallbackSVG(filename: escapedFilename, message: escapedMessage)
        }
    }

    nonisolated private static func xmlEscape(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }

    nonisolated private static func generateFallbackSVG(filename: String, message: String) -> String {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="350" height="90" viewBox="0 0 350 90">
          <rect width="100%" height="100%" fill="#fff3cd" stroke="#ffeeba" stroke-width="2" rx="6"/>
          <text x="50%" y="38%" dominant-baseline="middle" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="13" fill="#856404" font-weight="bold">⚠️ \(message)</text>
          <text x="50%" y="68%" dominant-baseline="middle" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="11" fill="#856404">\(filename)</text>
        </svg>
        """
        return "data:image/svg+xml;base64,\(Data(svg.utf8).base64EncodedString())"
    }

    nonisolated private static func pruneAssetCacheIfNeeded() {
        while assetCache.count > maxAssetCacheEntries || assetCacheBytes > maxAssetCacheBytes {
            guard let oldest = assetCache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) else {
                assetCacheBytes = 0
                return
            }
            assetCacheBytes -= oldest.value.byteCount
            assetCache[oldest.key] = nil
        }
    }

    nonisolated private static func absoluteFileURL(forAssetPath path: String, relativeTo directory: URL) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://")
            || lower.hasPrefix("data:") || lower.hasPrefix("file:") || lower.hasPrefix("mailto:") {
            return nil
        }

        let decoded = trimmed.removingPercentEncoding ?? trimmed
        let resolved = decoded.hasPrefix("/")
            ? URL(fileURLWithPath: decoded)
            : URL(fileURLWithPath: decoded, relativeTo: directory)
        let standardized = resolved.standardizedFileURL
        guard FileManager.default.fileExists(atPath: standardized.path) else { return nil }
        return standardized
    }

    /// Surface the real error (permissions / too large) instead of silently swallowing it.
    nonisolated private static func loadAssetData(at fileURL: URL) -> Result<Data, Error> {
        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else {
                return .failure(NSError(domain: "MarkdownViewer", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "empty file"]))
            }
            guard data.count <= 8_000_000 else {
                return .failure(NSError(domain: "MarkdownViewer", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "asset exceeds 8 MB limit"]))
            }
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    nonisolated private static func mimeType(forPreviewAsset pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }

    /// Drains Launch Services queue; returns the last URL when multiple files were queued.
    private static func lastQueuedOpenURL() -> URL? {
        var last: URL?
        while let url = AppDelegate.consumeQueuedOpenURL() {
            last = url
        }
        return last
    }

    var lineCount: Int {
        if text.isEmpty { return 0 }
        var count = 0
        text.enumerateLines { _, _ in count += 1 }
        return count
    }
}

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}
