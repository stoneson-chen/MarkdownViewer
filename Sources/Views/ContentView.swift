// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI
import UniformTypeIdentifiers

/// Main content view: preview-only by default, dual-pane when editing.
struct ContentView: View {
    @State private var viewModel = DocumentViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasLoadedInitialContent = false
    @State private var commandScope = WindowCommandScope()
    @State private var scrollSyncSequence = 0
    @State private var scrollSyncCommand: ScrollSyncCommand?
    @State private var scrollSyncPending: (source: ScrollSyncCommand.Source, percent: Double)?
    @State private var scrollSyncFlushTask: Task<Void, Never>?
    @State private var lastFlushedEditorPercent: Double = -1
    @State private var lastFlushedPreviewPercent: Double = -1
    @State private var isTypographyPresented = false
    @State private var isExportPresented = false
    @FocusState private var isSearchFieldFocused: Bool

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { self.viewModel.errorMessage != nil },
            set: { if !$0 { self.viewModel.errorMessage = nil } }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailContent
        }
        .navigationTitle("")
        .background(DocumentEditedWindowSync(
            isEdited: viewModel.isDirty,
            title: viewModel.displayedWindowTitle
        ))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                documentToolbarContent
            }
            searchToolbarContent
        }
        .task {
            guard !hasLoadedInitialContent else { return }
            hasLoadedInitialContent = true
            await viewModel.loadInitialContent()
        }
        .onAppear {
            AppDelegate.registerWindow(
                scope: commandScope,
                canReuse: { viewModel.canReuseForExternalOpen },
                openURL: { viewModel.openFile($0) }
            )
        }
        .onDisappear {
            AppDelegate.unregisterWindow(scope: commandScope)
        }
        .focusedValue(\.documentCommandActions, commandActions)
        .alert(String(localized: "common.error", bundle: .appResources), isPresented: isAlertPresented) {
            Button(String(localized: "common.ok", bundle: .appResources)) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            StatusBar(viewModel: viewModel)
        }
        .onChange(of: viewModel.fileURL) { _, newValue in
            if newValue != nil {
                withAnimation {
                    columnVisibility = .all
                }
            }
            resetScrollSyncState()
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            if isEditing {
                resetScrollSyncState()
            }
        }
        .onChange(of: viewModel.isSearchPresented) { _, isPresented in
            if isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFieldFocused = true
                }
            } else {
                isSearchFieldFocused = false
            }
        }
        .onChange(of: isSearchFieldFocused) { _, isFocused in
            if !isFocused {
                dismissSearchIfEmpty()
            }
        }
        .background(
            Button("") {
                presentSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
        )
        .background(
            Button("") {
                presentSearch()
            }
            .keyboardShortcut("f", modifiers: .control)
            .opacity(0)
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("exportDidFinish"))) { notification in
            guard notification.object as? WindowCommandScope === commandScope else { return }
            self.handleExportDidFinish(notification)
        }
    }

    private func resetScrollSyncState() {
        scrollSyncFlushTask?.cancel()
        scrollSyncPending = nil
        lastFlushedEditorPercent = -1
        lastFlushedPreviewPercent = -1
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        OutlineView(
            headings: viewModel.headings,
            activeHeadingID: viewModel.activeHeadingID
        ) { heading in
            viewModel.scrollToHeading(heading, scope: commandScope)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 350)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.isEditing {
            editingLayout
        } else {
            previewOnlyLayout
        }
    }

    private var previewOnlyLayout: some View {
        PreviewView(viewModel: viewModel, commandScope: commandScope, scrollSyncCommand: nil, onScroll: nil)
    }

    @ViewBuilder
    private var editingLayout: some View {
        switch viewModel.splitOrientation {
        case .horizontal:
            HSplitView {
                editorPane
                previewPane
            }
        case .vertical:
            VSplitView {
                editorPane
                previewPane
            }
        }
    }

    private var editorPane: some View {
        EditorView(viewModel: viewModel, text: Binding(
            get: { viewModel.text },
            set: { viewModel.textDidChange($0) }
        ), commandScope: commandScope, scrollSyncCommand: scrollSyncCommand) { percent in
            pushScrollSync(from: .editor, percent: percent)
        }
        .frame(minWidth: 280, minHeight: 200)
    }

    private var previewPane: some View {
        PreviewView(viewModel: viewModel, commandScope: commandScope, scrollSyncCommand: scrollSyncCommand) { percent in
            pushScrollSync(from: .preview, percent: percent)
        }
            .frame(minWidth: 280, minHeight: 200)
    }

    private func pushScrollSync(from source: ScrollSyncCommand.Source, percent: Double) {
        let clampedPercent = min(1.0, max(0.0, percent))
        scrollSyncPending = (source, clampedPercent)

        scrollSyncFlushTask?.cancel()
        scrollSyncFlushTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(ScrollSync.coalesceIntervalMs))
            guard !Task.isCancelled, let pending = scrollSyncPending else { return }
            flushScrollSync(source: pending.source, percent: pending.percent)
        }
    }

    private func flushScrollSync(source: ScrollSyncCommand.Source, percent: Double) {
        let last = source == .editor ? lastFlushedEditorPercent : lastFlushedPreviewPercent
        guard abs(percent - last) >= ScrollSync.minPercentDelta else { return }

        if source == .editor {
            lastFlushedEditorPercent = percent
        } else {
            lastFlushedPreviewPercent = percent
        }

        scrollSyncSequence += 1
        scrollSyncCommand = ScrollSyncCommand(
            source: source,
            percent: percent,
            sequence: scrollSyncSequence
        )
    }

    private var commandActions: DocumentCommandActions {
        DocumentCommandActions(
            isDirty: viewModel.isDirty,
            isEditing: viewModel.isEditing,
            openFile: { viewModel.openFilePanel() },
            saveFile: { viewModel.saveFile() },
            saveFileAs: { viewModel.saveFileAs() },
            toggleEditing: { viewModel.toggleEditing() },
            toggleSplitOrientation: { viewModel.toggleSplitOrientation() },
            formatBold: { postFormatCommand(.formatBold) },
            formatItalic: { postFormatCommand(.formatItalic) },
            formatCode: { postFormatCommand(.formatCode) },
            formatH1: { postFormatCommand(.formatH1) },
            formatH2: { postFormatCommand(.formatH2) },
            formatH3: { postFormatCommand(.formatH3) },
            formatLink: { postFormatCommand(.formatLink) },
            formatImage: { postFormatCommand(.formatImage) }
        )
    }

    private func postFormatCommand(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: commandScope)
    }

    // MARK: - Native Toolbar

    @ViewBuilder
    private var documentToolbarContent: some View {
        Button {
            viewModel.openFilePanel()
        } label: {
            Image(systemName: "doc.badge.plus")
        }
        .help(String(localized: "toolbar.openFile", bundle: .appResources))

        Button {
            viewModel.saveFile()
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .help(String(localized: "toolbar.saveFile", bundle: .appResources))

        Button {
            viewModel.toggleEditing()
        } label: {
            Image(systemName: viewModel.isEditing ? "eye.fill" : "pencil.line")
        }
        .help(
            viewModel.isEditing
                ? String(localized: "toolbar.previewMode", bundle: .appResources)
                : String(localized: "toolbar.editMode", bundle: .appResources)
        )

        if viewModel.isEditing {
            Button {
                viewModel.toggleSplitOrientation()
            } label: {
                Image(systemName: viewModel.splitOrientation.systemImage)
            }
            .help(String(localized: "toolbar.toggleSplit", bundle: .appResources))
        }

        Button {
            isTypographyPresented.toggle()
        } label: {
            Image(systemName: "textformat.size")
        }
        .help(String(localized: "typography.title", bundle: .appResources))
        .popover(isPresented: $isTypographyPresented, arrowEdge: .bottom) {
            TypographyPopoverView()
        }

        Button {
            isExportPresented.toggle()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help(String(localized: "export.title", bundle: .appResources))
            .popover(isPresented: $isExportPresented, arrowEdge: .bottom) {
                ExportPopoverView(commandScope: commandScope) { format, margin, includeTOC, syntaxHighlight, embedImages, applyCSS in
                handleExport(
                    format: format,
                    margin: margin,
                    includeTOC: includeTOC,
                    syntaxHighlight: syntaxHighlight,
                    embedImages: embedImages,
                    applyCSS: applyCSS
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var searchToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.isSearchPresented {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField(
                        String(localized: "search.placeholder", bundle: .appResources),
                        text: $viewModel.searchQuery
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFieldFocused)
                    .frame(width: 200)
                    .onSubmit {
                        viewModel.searchNext()
                    }
                    .onKeyPress { keyPress in
                        if keyPress.key == .escape {
                            closeSearch()
                            return .handled
                        }
                        return .ignored
                    }

                    if !viewModel.searchQuery.isEmpty {
                        Text("\(viewModel.totalSearchMatchesCount == 0 ? 0 : viewModel.currentSearchMatchIndex + 1)/\(viewModel.totalSearchMatchesCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .help(String(localized: "search.matchCount", bundle: .appResources))

                        Button {
                            viewModel.searchPrev()
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(viewModel.totalSearchMatchesCount == 0)
                        .help(String(localized: "search.prev", bundle: .appResources))

                        Button {
                            viewModel.searchNext()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(viewModel.totalSearchMatchesCount == 0)
                        .help(String(localized: "search.next", bundle: .appResources))
                    }

                    Button {
                        closeSearch()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .help(String(localized: "search.close", bundle: .appResources))
                }
            } else {
                Button {
                    presentSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help(String(localized: "search.placeholder", bundle: .appResources))
            }
        }
    }

    private func presentSearch() {
        viewModel.isSearchPresented = true
    }

    private func dismissSearchIfEmpty() {
        guard viewModel.searchQuery.isEmpty else { return }
        viewModel.isSearchPresented = false
    }

    private func closeSearch() {
        viewModel.isSearchPresented = false
    }

    private func handleExport(format: String, margin: Double, includeTOC: Bool, syntaxHighlight: Bool, embedImages: Bool, applyCSS: Bool) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = format == "pdf" ? [.pdf] : [UTType(filenameExtension: "docx") ?? UTType("org.openxmlformats.wordprocessingml.document")!]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = viewModel.fileURL?.deletingPathExtension().lastPathComponent ?? "document"
        
        let window = NSApp.keyWindow ?? NSApp.windows.first
        savePanel.beginSheetModal(for: window ?? NSWindow()) { response in
            if response == .OK, let url = savePanel.url {
                if format == "pdf" {
                    NotificationCenter.default.post(
                        name: .exportPDFRequest,
                        object: commandScope,
                        userInfo: [
                            "url": url,
                            "margin": margin,
                            "includeTOC": includeTOC
                        ]
                    )
                } else {
                    Task { @MainActor in
                        do {
                            let themeVars = switch UserDefaults.standard.string(forKey: "previewTheme") ?? "light" {
                            case "dark": PreviewThemes.darkVars
                            case "sepia": PreviewThemes.sepiaVars
                            case "ocean": PreviewThemes.oceanVars
                            default: PreviewThemes.lightVars
                            }
                            
                            let fontFamily = UserDefaults.standard.string(forKey: "editorFontFamily") ?? "SF Pro"
                            let fontSize = UserDefaults.standard.double(forKey: "editorFontSize")
                            let editorFontSize = fontSize > 0 ? fontSize : 15.0
                            let editorLineHeight = UserDefaults.standard.double(forKey: "editorLineHeight") > 0 ? UserDefaults.standard.double(forKey: "editorLineHeight") : 1.6
                            
                            let fontFamilyCSS = switch fontFamily {
                            case "SF Mono": "ui-monospace, monospace"
                            case "New York": "Georgia, serif"
                            default: "system-ui, -apple-system, sans-serif"
                            }
                            
                            var rules = themeVars.map { "\($0.key): \($0.value);" }.joined(separator: " ")
                            rules += " --font-family-base: \(fontFamilyCSS);"
                            rules += " --font-size-base: \(editorFontSize)px;"
                            rules += " --line-height-base: \(editorLineHeight);"
                            
                            let cssString = applyCSS ? viewModel.previewCSS : ""
                            let tocTitle = String(localized: "outline.title", bundle: .appResources)
                            let tocHTML = includeTOC
                                ? WebPreview.buildExportTOCHTML(headings: viewModel.headings, tocTitle: tocTitle)
                                : ""
                            let tocSection = tocHTML.isEmpty
                                ? ""
                                : "<nav class=\"export-toc\">\(tocHTML)</nav>"

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
                                /* MSO Word 高保真排版引线与边框样式支持 */
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
                            
                            let htmlData = exportHTML.data(using: .utf8)!
                            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                                .documentType: NSAttributedString.DocumentType.html,
                                .characterEncoding: String.Encoding.utf8.rawValue
                            ]
                            let attrStr = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
                            let docxData = try attrStr.data(
                                from: NSRange(location: 0, length: attrStr.length),
                                documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
                            )
                            try docxData.write(to: url)
                            
                            NotificationCenter.default.post(
                                name: Notification.Name("exportDidFinish"),
                                object: commandScope,
                                userInfo: ["success": true, "url": url]
                            )
                        } catch {
                            NotificationCenter.default.post(
                                name: Notification.Name("exportDidFinish"),
                                object: commandScope,
                                userInfo: ["success": false, "error": error.localizedDescription]
                            )
                        }
                    }
                }
            } else {
                NotificationCenter.default.post(name: Notification.Name("exportDidFinish"), object: commandScope)
            }
        }
    }

    private func handleExportDidFinish(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let success = userInfo["success"] as? Bool ?? false
        if success {
            let alert = NSAlert()
            alert.messageText = String(localized: "export.success", bundle: .appResources)
            if let url = userInfo["url"] as? URL {
                alert.informativeText = url.lastPathComponent
            }
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "common.ok", bundle: .appResources))
            alert.runModal()
        } else if let errorMsg = userInfo["error"] as? String {
            let alert = NSAlert()
            alert.messageText = String(localized: "export.failed", bundle: .appResources)
            alert.informativeText = errorMsg
            alert.alertStyle = .critical
            alert.addButton(withTitle: String(localized: "common.ok", bundle: .appResources))
            alert.runModal()
        }
    }
}

/// Syncs document dirty state and title to the native window chrome.
private struct DocumentEditedWindowSync: NSViewRepresentable {
    let isEdited: Bool
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        syncWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        syncWindow(for: nsView)
    }

    private func syncWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = title
            window.isDocumentEdited = isEdited
        }
    }
}
