import Foundation
import SwiftUI

/// Core ViewModel managing file state, editing mode, and preview rendering.
@Observable
@MainActor
final class DocumentViewModel {
    // MARK: - Services

    let fileService = FileService()
    // MARK: - Content State

    /// The markdown source text
    var text: String = ""

    /// Rendered HTML for the WKWebView preview
    private(set) var renderedHTML: String = ""
    private(set) var wordCount: Int = 0
    private(set) var characterCount: Int = 0
    private(set) var headings: [MarkdownParser.Heading] = []
    private(set) var isRendering = false
    
    /// 当前正在阅读的标题 ID（用于侧边栏高亮）
    var activeHeadingID: String?

    // MARK: - File State

    /// Currently opened file URL; nil when showing default README
    var fileURL: URL? {
        didSet { updateWindowTitle(); _cachedCSS = nil; _cachedBase = nil }
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
        didSet { _cachedCSS = nil }
    }

    /// Window title
    private(set) var windowTitle: String = "README.md"

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
    private var _cachedBase: (baseURL: URL?, basePath: String)?
    private var originalText: String = ""
    private var parseRevision = 0

    /// Bumps when a new on-disk file load should own sidebar security scope / completion.
    private var sidebarDirLoadGeneration = 0
    /// Keeps `startAccessingSecurityScopedResource` active on the opened document while the sidebar enumerates its parent directory (see `FileService.loadFolder`).
    private var retainedSidebarSecurityFileURL: URL?

    private enum DefaultsKey {
        static let customCSSBookmark = "userCustomCSSBookmark"
    }

    init() {
        fileService.onFolderDidChange = { [weak self] in
            self?._cachedBase = nil
        }
    }

    // MARK: - Lifecycle

    /// Load default content on init. Called once.
    func loadInitialContent() async {
        // If a file was already opened, don't overwrite it.
        if fileURL != nil { return }

        if let url = AppDelegate.consumeQueuedOpenURL() {
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

        if let url = AppDelegate.consumeQueuedOpenURL() {
            openFile(url)
            return
        }

        // Only use README as filler when no external URL/file input exists.
        loadDefaultReadme()
    }

    // MARK: - File Operations

    /// Load the bundled README.md
    func loadDefaultReadme() {
        endRetainedSidebarSecurityScope()
        if let url = Bundle.appResources.url(forResource: "README", withExtension: "md"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            text = content
        } else {
            text = fallbackReadme
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
        if fileURL?.standardized == target {
            _ = syncFolderSidebar(for: target, parentURL: nil, retainedAccessGeneration: nil)
            return
        }
        if pendingOpenURL == target { return }

        debounceTask?.cancel()
        parseRevision += 1
        pendingOpenURL = target

        Task {
            do {
                defer { pendingOpenURL = nil }
                
                // Perform file access and reading on a background task
                let (content, parentURL) = try await Task.detached(priority: .userInitiated) {
                    try Self.withSecurityScopedAccess(to: target) {
                        let data = try String(contentsOf: target, encoding: .utf8)
                        let parent = target.deletingLastPathComponent()
                        return (data, parent)
                    }
                }.value

                self.text = content
                self.fileURL = target
                self.originalText = content
                self.isDirty = false
                self.isRendering = true

                // Phase 1: fast partial preview (MainActor)
                let quick = parser.parseFirstChunk(content, lineLimit: 200)
                renderedHTML = quick.html
                characterCount = content.count

                // Phase 2: full parse on background
                let revision = nextParseRevision()
                Task { await runAsyncParse(content, skipWordCount: false, revision: revision) }

                sidebarDirLoadGeneration += 1
                let loadGen = sidebarDirLoadGeneration
                beginRetainedSidebarSecurityScope(for: target)
                let scheduled = syncFolderSidebar(for: target, parentURL: parentURL, retainedAccessGeneration: loadGen)
                if !scheduled {
                    endRetainedSidebarSecurityScope()
                }
            } catch {
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

        do {
            try Self.withSecurityScopedAccess(to: url) {
                try text.write(to: url, atomically: true, encoding: .utf8)
            }
            originalText = text
            isDirty = false
        } catch {
            errorMessage = String(localized: "error.save", bundle: .appResources) + error.localizedDescription
        }
    }

    /// Save As: prompt for new location
    func saveFileAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdown]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try Self.withSecurityScopedAccess(to: url) {
                try text.write(to: url, atomically: true, encoding: .utf8)
            }
            fileURL = url
            originalText = text
            isDirty = false
        } catch {
            errorMessage = String(localized: "error.saveAs", bundle: .appResources) + error.localizedDescription
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
            await parseFull(skipWordCount: false)
        }
    }

    /// Progressive: sync Phase 1 for instant preview, then async Phase 2.
    private func parseProgressive() async {
        let markdown = self.text

        // Phase 1: SYNC on MainActor — limited lines for instant response
        let quick = parser.parseFirstChunk(markdown, lineLimit: 50)
        renderedHTML = quick.html
        characterCount = markdown.count

        // Phase 2: full parse on background
        isRendering = true
        let revision = nextParseRevision()
        await runAsyncParse(markdown, skipWordCount: false, revision: revision)
    }

    private func parseFull(skipWordCount: Bool) async {
        let markdown = self.text
        let revision = nextParseRevision()
        isRendering = true
        await runAsyncParse(markdown, skipWordCount: skipWordCount, revision: revision)
    }

    /// Shared async parse runner — single code path for all full-parse calls.
    private func runAsyncParse(_ markdown: String, skipWordCount: Bool, revision: Int) async {
        let parser = self.parser
        let result = await Task.detached(priority: .userInitiated) {
            await parser.parse(markdown, skipWordCount: skipWordCount)
        }.value

        guard revision == parseRevision else { return }
        renderedHTML = result.html
        if !skipWordCount {
            wordCount = result.wordCount
        }
        characterCount = result.characterCount
        headings = result.headings
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
            name: .scrollToHeading,
            object: scope,
            userInfo: ["anchorID": heading.anchorID]
        )
    }

    // MARK: - CSS Resolution
    
    /// Resolve the CSS to use for preview: per-file CSS → settings CSS → default
    func resolvedCSS() -> String {
        if let cached = _cachedCSS { return cached }
        let css: String
        // 1. Check for per-file CSS (same name, .css extension)
        if let fileURL = fileURL {
            let cssURL = fileURL.deletingPathExtension().appendingPathExtension("css")
            if let perFileCSS = try? Self.withSecurityScopedAccess(to: fileURL, {
                try String(contentsOf: cssURL, encoding: .utf8)
            }) {
                css = perFileCSS
                _cachedCSS = css
                return css
            }
        }
        // 2. Check settings custom CSS path
        if let cssURL = Self.resolveSecurityScopedBookmark(forKey: DefaultsKey.customCSSBookmark)
            ?? (!customCSSPath.isEmpty ? URL(fileURLWithPath: customCSSPath) : nil) {
            if let userCSS = try? Self.withSecurityScopedAccess(to: cssURL, {
                try String(contentsOf: cssURL, encoding: .utf8)
            }) {
                css = userCSS
                _cachedCSS = css
                return css
            }
        }
        // 3. Default bundled CSS
        if let url = Bundle.appResources.url(forResource: "default", withExtension: "css"),
           let defaultCSS = try? String(contentsOf: url, encoding: .utf8) {
            css = defaultCSS
            _cachedCSS = css
            return css
        }
        // Don't cache empty CSS — allows retry on next call
        return ""
    }

    // MARK: - Base URL Resolution for Preview

    /// Returns the (baseURL, basePath) for WKWebView.
    /// baseURL is the highest authorized directory we can use as origin.
    /// basePath is the relative path from baseURL to the markdown file's directory.
    func resolveRenderingBase() -> (baseURL: URL?, basePath: String) {
        if let cached = _cachedBase { return cached }
        let result = computeRenderingBase()
        _cachedBase = result
        return result
    }

    private func computeRenderingBase() -> (baseURL: URL?, basePath: String) {
        guard let fileURL = fileURL else { return (nil, "") }
        
        let fileDir = fileURL.deletingLastPathComponent().standardized
        
        // If we have a folder open in the sidebar, use it as root to allow relative paths above the file
        if let rootURL = fileService.currentFolderURL?.standardized {
            let rootPath = rootURL.path(percentEncoded: false)
            let filePath = fileURL.path(percentEncoded: false)
            
            if Self.path(filePath, isInsideOrEqualTo: rootPath) {
                // File is inside the root folder.
                let fileDirPath = fileDir.path(percentEncoded: false)
                let relativePath = String(fileDirPath.dropFirst(rootPath.count))
                
                let parts = relativePath.components(separatedBy: "/")
                    .filter { !$0.isEmpty }
                
                let encodedParts = parts.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
                let basePath = encodedParts.isEmpty ? "" : encodedParts.joined(separator: "/") + "/"
                
                return (rootURL, basePath)
            }
        }
        
        // Fallback: Use the file's directory as root
        return (fileDir, "")
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

    @discardableResult
    private func syncFolderSidebar(
        for fileURL: URL,
        parentURL: URL? = nil,
        retainedAccessGeneration: Int? = nil
    ) -> Bool {
        let parentURL = (parentURL ?? fileURL.deletingLastPathComponent()).standardized

        // Always create a minimal tree showing at least the current file.
        // This guarantees the Files tab is never blank, even if async loadFolder fails.
        if fileService.rootNode == nil || fileService.currentFolderURL?.standardized != parentURL {
            fileService.setPlaceholderTree(for: parentURL, selectedFile: fileURL)
        }

        if let currentFolder = fileService.currentFolderURL?.standardized {
            let currentPath = currentFolder.path(percentEncoded: false)
            let filePath = fileURL.path(percentEncoded: false)
            // Do not skip `loadFolder` while only a placeholder tree is shown (`rootNode != nil` alone is insufficient).
            if Self.path(filePath, isInsideOrEqualTo: currentPath),
               fileService.completedFolderLoadURL?.standardized == currentFolder,
               fileService.rootNode != nil {
                return false
            }
        }

        let onLoadFinished: (@MainActor () -> Void)?
        if let gen = retainedAccessGeneration {
            onLoadFinished = { [weak self] in
                guard let self else { return }
                guard gen == self.sidebarDirLoadGeneration else { return }
                self.endRetainedSidebarSecurityScope()
            }
        } else {
            onLoadFinished = nil
        }

        fileService.loadFolder(at: parentURL, selecting: fileURL, onLoadFinished: onLoadFinished)
        return true
    }

    private func beginRetainedSidebarSecurityScope(for fileURL: URL) {
        endRetainedSidebarSecurityScope()
        let url = fileURL.standardized
        if url.startAccessingSecurityScopedResource() {
            retainedSidebarSecurityFileURL = url
        }
    }

    private func endRetainedSidebarSecurityScope() {
        if let url = retainedSidebarSecurityFileURL {
            url.stopAccessingSecurityScopedResource()
            retainedSidebarSecurityFileURL = nil
        }
    }

    private nonisolated static func withSecurityScopedAccess<T>(
        to url: URL,
        _ body: () throws -> T
    ) rethrows -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }

    private nonisolated static func resolveSecurityScopedBookmark(forKey key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private nonisolated static func path(_ path: String, isInsideOrEqualTo rootPath: String) -> Bool {
        if path == rootPath { return true }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return path.hasPrefix(prefix)
    }

    var lineCount: Int {
        if text.isEmpty { return 0 }
        var count = 0
        text.enumerateLines { _, _ in count += 1 }
        return count
    }

    private let fallbackReadme = """
    # 墨阅 (MarkdownViewer)

    > **墨色生香，阅见不凡。**

    一款为 macOS 精心打造的轻量级 Markdown 预览器。

    - 默认纯预览模式，切换编辑后支持双栏实时预览
    - 支持自定义 CSS 样式表
    - 命令行打开：`open -a "墨阅" file.md`
    """
}
