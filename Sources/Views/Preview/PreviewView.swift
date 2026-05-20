// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI
import WebKit

/// Renders Markdown as styled HTML in a WKWebView with CSS support.
struct PreviewView: View {
    @Bindable var viewModel: DocumentViewModel
    let commandScope: WindowCommandScope
    let scrollSyncCommand: ScrollSyncCommand?
    let onScroll: ((Double) -> Void)?
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebPreview(
                html: viewModel.renderedHTML,
                css: viewModel.previewCSS,
                baseURL: viewModel.resolveRenderingBase(),
                scrollSessionKey: viewModel.fileURL?.path ?? "__default__",
                appTheme: appTheme,
                commandScope: commandScope,
                scrollSyncCommand: scrollSyncCommand,
                onScroll: onScroll
            )

            if viewModel.isRendering {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.isRendering)
        .onReceive(NotificationCenter.default.publisher(for: .didDetectHeading)) { notification in
            if notification.object as? WindowCommandScope === commandScope,
               let anchorID = notification.userInfo?["anchorID"] as? String {
                viewModel.activeHeadingID = anchorID
            }
        }
    }
}

// MARK: - WKWebView Wrapper

struct WebPreview: NSViewRepresentable {
    let html: String
    let css: String
    let baseURL: URL?
    let scrollSessionKey: String
    let appTheme: AppTheme
    let commandScope: WindowCommandScope
    let scrollSyncCommand: ScrollSyncCommand?
    let onScroll: ((Double) -> Void)?

    /// `mermaid.min.js` loaded once and injected as a `WKUserScript` (saves ~3 MB of string allocation per reload).
    /// Lives on the configuration so it's shared by every navigation in the web view.
    private static let mermaidUserScript: WKUserScript? = {
        guard let url = Bundle.appResources.url(forResource: "mermaid", withExtension: "min.js"),
              let source = try? String(contentsOf: url, encoding: .utf8), !source.isEmpty else { return nil }
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }()

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(false, forKey: "developerExtrasEnabled")
#if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        config.userContentController.add(context.coordinator, name: "headingInView")
        config.userContentController.add(context.coordinator, name: "previewScroll")
        if let mermaid = Self.mermaidUserScript {
            config.userContentController.addUserScript(mermaid)
        }
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.webView = webView
        context.coordinator.onScroll = onScroll
        applyAppearance(to: webView, theme: appTheme)

        let needsFullReload = context.coordinator.lastCSS != css
                             || context.coordinator.lastDocumentBaseURL != baseURL
                             || context.coordinator.lastScrollSessionKey != scrollSessionKey
                             || context.coordinator.lastAppTheme != appTheme
                             || context.coordinator.lastBody != html

        if needsFullReload && !html.isEmpty {
            context.coordinator.lastCSS = css
            context.coordinator.lastDocumentBaseURL = baseURL
            context.coordinator.lastScrollSessionKey = scrollSessionKey
            context.coordinator.lastAppTheme = appTheme
            context.coordinator.lastBody = html

            let fullHTML = wrapInHTMLTemplate(
                body: html,
                css: css,
                documentBaseURL: baseURL,
                scrollSessionKey: scrollSessionKey
            )
            context.coordinator.loadPreview(html: fullHTML, in: webView, baseURL: baseURL)
        }

        if context.coordinator.scrollObserver == nil {
            context.coordinator.setupScrollListener()
        }

        if let scrollSyncCommand {
            context.coordinator.applyScrollCommandIfNeeded(scrollSyncCommand, in: webView)
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "headingInView")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "previewScroll")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(commandScope: commandScope)
    }

    // MARK: - HTML Template

    /// `file://` base for resolving relative links in the preview.
    private func documentBaseHref(for documentBaseURL: URL?) -> String {
        guard let documentBaseURL else { return "" }
        var href = documentBaseURL.absoluteString
        if !href.hasSuffix("/") { href += "/" }
        return href.replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func jsStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    private func wrapInHTMLTemplate(
        body: String,
        css: String,
        documentBaseURL: URL?,
        scrollSessionKey: String
    ) -> String {
        let baseHref = documentBaseHref(for: documentBaseURL)
        let mmThemeString = switch appTheme {
            case .dark: "dark"
            case .light: "default"
            case .system: "auto"
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="default-src 'self'; img-src file: data: https: http:; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
            <base href="\(baseHref)">
            <link rel="icon" href="data:,">
            <style>
            \(css)
            html { scroll-behavior: smooth; }

            /* Syntax Highlighting */
            .hl-keyword  { color: #d73a49; font-weight: 600; }
            .hl-string   { color: #032f62; }
            .hl-comment  { color: #6a737d; font-style: italic; }
            .hl-number   { color: #005cc5; }
            .hl-type     { color: #6f42c1; }
            .hl-func     { color: #6f42c1; }
            .hl-builtin  { color: #005cc5; }
            @media (prefers-color-scheme: dark) {
                .hl-keyword  { color: #ff7b72; }
                .hl-string   { color: #a5d6ff; }
                .hl-comment  { color: #8b949e; }
                .hl-number   { color: #79c0ff; }
                .hl-type     { color: #d2a8ff; }
                .hl-func     { color: #d2a8ff; }
                .hl-builtin  { color: #79c0ff; }
            }

            /* Mermaid */
            .mermaid { text-align: center; margin: 1.2em 0; overflow-x: auto; }
            .mermaid svg { max-width: 100%; height: auto; }
            </style>
            \(themeOverrideStyle())
        </head>
        <body>
            <article id="content" class="markdown-body">
            \(body)
            </article>
            <script>
            function scrollToAnchor(id) {
                const el = document.getElementById(id);
                if (el) {
                    const offset = el.getBoundingClientRect().top + window.pageYOffset - 20;
                    window.scrollTo({ top: offset, behavior: 'auto' });
                }
            }

            /// Editor→preview scroll sync (called from Swift).
            function mdviewerScrollToPercent(pct) {
                const p = Math.min(1, Math.max(0, Number(pct) || 0));
                const scroller = document.scrollingElement || document.documentElement || document.body;
                const maxScroll = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
                const target = maxScroll * p;
                scroller.scrollTop = target;
                window.scrollTo(0, target);
                return { top: scroller.scrollTop, y: window.scrollY, maxScroll: maxScroll, target: target, pct: p };
            }

            /// Apply editor-driven scroll without echoing back to Swift.
            function mdviewerApplyRemoteScroll(pct) {
                window.__mdviewerSuppressScrollReport = true;
                const result = mdviewerScrollToPercent(pct);
                requestAnimationFrame(function() {
                    window.__mdviewerSuppressScrollReport = false;
                });
                return result;
            }

            // Preserve scroll position across updates (per document)
            var scrollKey = 'mdviewer_scroll_\(jsStringLiteral(scrollSessionKey))';
            var saved = sessionStorage.getItem(scrollKey);
            if (saved) window.scrollTo(0, parseInt(saved));
            var lastReportedPreviewPct = -1;
            var previewScrollReportScheduled = false;
            window.addEventListener('scroll', function() {
                const scroller = document.scrollingElement || document.documentElement || document.body;
                sessionStorage.setItem(scrollKey, String(scroller.scrollTop));
                if (window.__mdviewerSuppressScrollReport) return;
                if (previewScrollReportScheduled) return;
                previewScrollReportScheduled = true;
                requestAnimationFrame(function() {
                    previewScrollReportScheduled = false;
                    if (window.__mdviewerSuppressScrollReport) return;
                    const maxScroll = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
                    const pct = maxScroll > 0 ? scroller.scrollTop / maxScroll : 0;
                    if (!Number.isFinite(pct)) return;
                    if (Math.abs(pct - lastReportedPreviewPct) < \(ScrollSync.minPercentDelta)) return;
                    lastReportedPreviewPct = pct;
                    window.webkit.messageHandlers.previewScroll.postMessage(pct);
                });
            }, { passive: true });

            // Intersection Observer for heading tracking
            const observerOptions = { root: null, rootMargin: '-10% 0px -85% 0px', threshold: 0 };
            let lastSentId = '';
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting && entry.target.id && entry.target.id !== lastSentId) {
                        lastSentId = entry.target.id;
                        window.webkit.messageHandlers.headingInView.postMessage(entry.target.id);
                    }
                });
            }, observerOptions);
            document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(h => {
                if (h.id) observer.observe(h);
            });

            // Mermaid diagram support (mermaid.min.js is injected by WKUserScript before document start)
            var mmTheme = '\(mmThemeString)';
            if (mmTheme === 'auto') {
                mmTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
            }
            if (typeof mermaid !== 'undefined') {
                // securityLevel 'loose' is acceptable here: content is local user-authored Markdown rendered in WKWebView.
                mermaid.initialize({ startOnLoad: false, theme: mmTheme, securityLevel: 'loose' });
            }

            // Lightweight syntax highlighter
            function highlightCode() {
                const keywords = ['func', 'var', 'let', 'const', 'if', 'else', 'for', 'while',
                    'return', 'class', 'struct', 'enum', 'import', 'export', 'def', 'async', 'await',
                    'try', 'catch', 'throw', 'switch', 'case', 'break', 'continue', 'guard',
                    'public', 'private', 'static', 'final', 'override', 'extension', 'protocol',
                    'where', 'in', 'is', 'as', 'true', 'false', 'nil', 'null', 'undefined', 'self', 'this'];
                const types = ['String', 'Int', 'Bool', 'Double', 'Float', 'Void', 'Any', 'Object',
                    'Array', 'Dictionary', 'Set', 'Optional', 'Result', 'Error', 'URL', 'Data'];
                const builtins = ['print', 'fatalError', 'Precondition', 'assert', 'map', 'filter',
                    'reduce', 'forEach', 'compactMap', 'flatMap', 'sorted', 'contains', 'console.log'];

                document.querySelectorAll('pre code[class*="language-"]').forEach(function(block) {
                    if (block.className.includes('language-mermaid')) return;
                    var lang = block.className.match(/language-(\\w+)/);
                    if (!lang) return;
                    var code = block.innerHTML;
                    var highlighted = '';
                    var i = 0;
                    while (i < code.length) {
                        // Comments
                        if (code[i] === '/' && code[i+1] === '/') {
                            var end = code.indexOf('\\n', i);
                            if (end === -1) end = code.length;
                            highlighted += '<span class="hl-comment">' + code.slice(i, end) + '</span>';
                            i = end;
                            continue;
                        }
                        if (code[i] === '/' && code[i+1] === '*') {
                            var end = code.indexOf('*/', i+2);
                            if (end === -1) end = code.length - 2;
                            highlighted += '<span class="hl-comment">' + code.slice(i, end+2) + '</span>';
                            i = end + 2;
                            continue;
                        }
                        // Strings
                        if (code[i] === '"' || code[i] === "'") {
                            var q = code[i], end = i + 1;
                            while (end < code.length && code[end] !== q) {
                                if (code[end] === '\\\\') end++;
                                end++;
                            }
                            end = Math.min(end + 1, code.length);
                            highlighted += '<span class="hl-string">' + code.slice(i, end) + '</span>';
                            i = end;
                            continue;
                        }
                        // Numbers
                        if (/[0-9]/.test(code[i]) && (i === 0 || /[\\s(\\[{=+\\-*\\/<>!?:;,|&^%]/.test(code[i-1]))) {
                            var end = i;
                            while (end < code.length && /[0-9.x_]/i.test(code[end])) end++;
                            highlighted += '<span class="hl-number">' + code.slice(i, end) + '</span>';
                            i = end;
                            continue;
                        }
                        // Words
                        if (/[a-zA-Z_]/.test(code[i])) {
                            var end = i + 1;
                            while (end < code.length && /[a-zA-Z0-9_]/.test(code[end])) end++;
                            var word = code.slice(i, end);
                            if (keywords.indexOf(word) !== -1) {
                                highlighted += '<span class="hl-keyword">' + word + '</span>';
                            } else if (types.indexOf(word) !== -1) {
                                highlighted += '<span class="hl-type">' + word + '</span>';
                            } else if (builtins.indexOf(word) !== -1) {
                                highlighted += '<span class="hl-builtin">' + word + '</span>';
                            } else if (code[end] === '(') {
                                highlighted += '<span class="hl-func">' + word + '</span>';
                            } else {
                                highlighted += word;
                            }
                            i = end;
                            continue;
                        }
                        highlighted += code[i];
                        i++;
                    }
                    block.innerHTML = highlighted;
                });
            }
            requestAnimationFrame(highlightCode);
            requestAnimationFrame(renderMermaid);

            function renderMermaid() {
                if (typeof mermaid === 'undefined') return;
                document.querySelectorAll('pre code.language-mermaid').forEach(function(block) {
                    var pre = block.parentElement;
                    var div = document.createElement('div');
                    div.className = 'mermaid';
                    div.textContent = block.textContent;
                    pre.parentElement.replaceChild(div, pre);
                });
                if (document.querySelectorAll('.mermaid').length > 0) {
                    try { mermaid.run({ querySelector: '.mermaid' }); } catch(e) { console.warn('Mermaid render error:', e); }
                }
            }
            </script>
        </body>
        </html>
        """
    }

    private func applyAppearance(to webView: WKWebView, theme: AppTheme) {
        switch theme {
        case .dark:
            webView.appearance = NSAppearance(named: .darkAqua)
        case .light:
            webView.appearance = NSAppearance(named: .aqua)
        case .system:
            webView.appearance = nil
        }
    }

    /// Inject explicit CSS variable overrides when user selects a specific theme.
    private func themeOverrideStyle() -> String {
        let vars: [String: String]
        switch appTheme {
        case .dark: vars = [
            "--text-primary": "#f5f5f7", "--text-secondary": "#a1a1a6",
            "--bg-primary": "#1d1d1f", "--bg-code": "#2c2c2e",
            "--bg-blockquote": "#2c2c2e", "--border-color": "#424245",
            "--accent-color": "#2997ff", "--accent-hover": "#64b5f6",
            "--heading-color": "#f5f5f7", "--code-color": "#ff6b9d", "--link-color": "#2997ff"]
        case .light: vars = [
            "--text-primary": "#1d1d1f", "--text-secondary": "#6e6e73",
            "--bg-primary": "#ffffff", "--bg-code": "#f5f5f7",
            "--bg-blockquote": "#f9f9fb", "--border-color": "#d2d2d7",
            "--accent-color": "#0071e3", "--accent-hover": "#0077ed",
            "--heading-color": "#1d1d1f", "--code-color": "#d63384", "--link-color": "#0071e3"]
        case .system: return ""
        }
        let rules = vars.map { "\($0.key): \($0.value);" }.joined(separator: " ")
        return "<style>:root { \(rules) }</style>"
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, @unchecked Sendable {
        private let commandScope: WindowCommandScope
        var lastBody: String = ""
        var lastCSS: String = ""
        var lastDocumentBaseURL: URL?
        var lastScrollSessionKey: String?
        var lastAppTheme: AppTheme?

        weak var webView: WKWebView?
        var onScroll: ((Double) -> Void)?
        private var isApplyingRemoteScroll = false
        private var remoteScrollResetTask: Task<Void, Never>?
        private var lastAppliedScrollSequence: Int?
        /// Latest editor scroll percent; reapplied after each preview HTML load finishes.
        private var pendingEditorScrollPercent: Double?
        private var isPageReady = false
        private var scrollApplyTask: Task<Void, Never>?
        private var lastAppliedLiveScrollPercent: Double = -1

        /// Load preview HTML. Local images are inlined as data URLs in `DocumentViewModel`; `baseURL` resolves other relative links.
        func loadPreview(html: String, in webView: WKWebView, baseURL: URL?) {
            isPageReady = false
            webView.loadHTMLString(html, baseURL: baseURL)
        }
        nonisolated(unsafe) var scrollObserver: (any NSObjectProtocol)?

        init(commandScope: WindowCommandScope) {
            self.commandScope = commandScope
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "headingInView", let anchorID = message.body as? String {
                NotificationCenter.default.post(
                    name: .didDetectHeading,
                    object: commandScope,
                    userInfo: ["anchorID": anchorID]
                )
            }
            if message.name == "previewScroll", let percent = message.body as? Double {
                guard !isApplyingRemoteScroll else { return }
                onScroll?(percent)
            }
        }

        func setupScrollListener() {
            scrollObserver = NotificationCenter.default.addObserver(
                forName: .executeScrollJS,
                object: commandScope,
                queue: .main
            ) { [weak self] notification in
                if let anchorID = notification.userInfo?["anchorID"] as? String {
                    Task { @MainActor in
                        _ = try? await self?.webView?.evaluateJavaScript("scrollToAnchor('\(anchorID)')")
                    }
                }
            }
        }

        func applyScrollCommandIfNeeded(_ command: ScrollSyncCommand, in webView: WKWebView) {
            guard command.source == .editor else { return }
            guard lastAppliedScrollSequence != command.sequence else { return }
            lastAppliedScrollSequence = command.sequence
            pendingEditorScrollPercent = command.percent

            if !isPageReady && !webView.isLoading {
                isPageReady = true
            }
            if webView.isLoading || !isPageReady {
                return
            }
            applyLiveEditorScroll(command.percent, in: webView)
        }

        deinit {
            remoteScrollResetTask?.cancel()
            scrollApplyTask?.cancel()
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
            applyScrollAfterNavigation(in: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        private func scheduleRemoteScrollReset() {
            remoteScrollResetTask?.cancel()
            remoteScrollResetTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(ScrollSync.remoteScrollGuardMs))
                self?.isApplyingRemoteScroll = false
            }
        }

        /// Live editor drag: single JS apply, no retry sleeps, no native double-scroll.
        private func applyLiveEditorScroll(_ percent: Double, in webView: WKWebView) {
            let clamped = min(1.0, max(0.0, percent))
            guard abs(clamped - lastAppliedLiveScrollPercent) >= ScrollSync.minPercentDelta else { return }

            scrollApplyTask?.cancel()
            isApplyingRemoteScroll = true
            scheduleRemoteScrollReset()

            scrollApplyTask = Task { @MainActor [webView] in
                if let metrics = await runJavaScriptScroll(clamped, in: webView, suppressReport: true),
                   metrics.maxScroll > 1 {
                    lastAppliedLiveScrollPercent = clamped
                    return
                }
                applyNativeScroll(clamped, in: webView, jsTarget: nil)
                lastAppliedLiveScrollPercent = clamped
            }
        }

        /// After HTML reload: layout may settle late — retry a few times only here.
        private func applyScrollAfterNavigation(in webView: WKWebView) {
            guard let percent = pendingEditorScrollPercent else { return }

            scrollApplyTask?.cancel()
            scrollApplyTask = Task { @MainActor [webView] in
                isApplyingRemoteScroll = true
                defer { scheduleRemoteScrollReset() }

                let clamped = min(1.0, max(0.0, percent))
                for attempt in 1...4 {
                    if Task.isCancelled { return }

                    if let metrics = await runJavaScriptScroll(clamped, in: webView, suppressReport: true),
                       metrics.maxScroll > 1 {
                        lastAppliedLiveScrollPercent = clamped
                        return
                    }

                    if attempt < 4 {
                        try? await Task.sleep(for: .milliseconds(attempt == 1 ? 16 : 48))
                    }
                }

                applyNativeScroll(clamped, in: webView, jsTarget: nil)
                lastAppliedLiveScrollPercent = clamped
            }
        }

        private struct JSScrollMetrics {
            let maxScroll: Double
            let target: Double
        }

        private func runJavaScriptScroll(
            _ percent: Double,
            in webView: WKWebView,
            suppressReport: Bool
        ) async -> JSScrollMetrics? {
            let call = suppressReport
                ? "mdviewerApplyRemoteScroll(\(percent))"
                : "mdviewerScrollToPercent(\(percent))"
            do {
                let value = try await webView.evaluateJavaScript(call)
                guard let dict = value as? [String: Any] else { return nil }
                let maxScroll = (dict["maxScroll"] as? NSNumber)?.doubleValue ?? 0
                let target = (dict["target"] as? NSNumber)?.doubleValue ?? 0
                return JSScrollMetrics(maxScroll: maxScroll, target: target)
            } catch {
                return nil
            }
        }

        /// Fallback when DOM scroll does not move the AppKit scroller (AX-visible). Uses JS `target` when available.
        private func applyNativeScroll(_ percent: Double, in webView: WKWebView, jsTarget: Double?) {
            guard let scrollView = Self.bestScrollView(in: webView) else {
                AppLog.scroll.debug("PreviewView native scroll skipped: no usable NSScrollView in WKWebView tree")
                return
            }

            let visibleHeight = scrollView.contentView.bounds.height
            let documentHeight = scrollView.documentView?.frame.height
                ?? scrollView.documentView?.bounds.height
                ?? scrollView.contentView.documentRect.height
            let scrollableHeight = max(0, documentHeight - visibleHeight)
            guard scrollableHeight > 1 else {
                AppLog.scroll.debug("PreviewView native scroll skipped: scrollableHeight=\(scrollableHeight, privacy: .public)")
                return
            }

            let targetY: CGFloat
            if let jsTarget, jsTarget > 0 {
                targetY = CGFloat(min(jsTarget, scrollableHeight))
            } else {
                targetY = CGFloat(min(1.0, max(0.0, percent))) * scrollableHeight
            }

            AppLog.scroll.debug("PreviewView native scroll targetY=\(targetY, privacy: .public) scrollableHeight=\(scrollableHeight, privacy: .public)")
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        /// Pick the scroll view with the largest scrollable document (not merely the first subview).
        private static func bestScrollView(in root: NSView) -> NSScrollView? {
            var best: NSScrollView?
            var bestScrollable: CGFloat = 0

            func visit(_ view: NSView) {
                if let scrollView = view as? NSScrollView {
                    let visible = scrollView.contentView.bounds.height
                    let documentHeight = scrollView.documentView?.frame.height
                        ?? scrollView.documentView?.bounds.height
                        ?? scrollView.contentView.documentRect.height
                    let scrollable = max(0, documentHeight - visible)
                    if scrollable > bestScrollable {
                        bestScrollable = scrollable
                        best = scrollView
                    }
                }
                for subview in view.subviews {
                    visit(subview)
                }
            }

            visit(root)
            return best
        }
    }
}
