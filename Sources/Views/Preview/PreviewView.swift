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
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some View {
        ZStack(alignment: .topTrailing) {
            let base = viewModel.resolveRenderingBase()
            WebPreview(
                html: viewModel.renderedHTML,
                css: viewModel.resolvedCSS(),
                baseURL: base.baseURL,
                basePath: base.basePath,
                appTheme: appTheme,
                commandScope: commandScope
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
        .onReceive(NotificationCenter.default.publisher(for: .scrollToHeading)) { notification in
            if notification.object as? WindowCommandScope === commandScope,
               let anchorID = notification.userInfo?["anchorID"] as? String {
                NotificationCenter.default.post(
                    name: .executeScrollJS,
                    object: commandScope,
                    userInfo: ["anchorID": anchorID]
                )
            }
        }
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
    let basePath: String
    let appTheme: AppTheme
    let commandScope: WindowCommandScope

    /// mermaid.min.js loaded once from the app bundle (thread-safe lazy static).
    private static let mermaidJS: String = {
        guard let url = Bundle.appResources.url(forResource: "mermaid", withExtension: "min.js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return js
    }()

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(false, forKey: "developerExtrasEnabled")
#if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        config.userContentController.add(context.coordinator, name: "headingInView")
        config.userContentController.add(context.coordinator, name: "previewScroll")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.webView = webView
        
        let needsFullReload = context.coordinator.lastCSS != css
                             || context.coordinator.lastBasePath != basePath
                             || context.coordinator.lastAppTheme != appTheme
                             || context.coordinator.lastBody != html

        if needsFullReload && !html.isEmpty {
            context.coordinator.lastCSS = css
            context.coordinator.lastBasePath = basePath
            context.coordinator.lastAppTheme = appTheme
            context.coordinator.lastBody = html

            let fullHTML = wrapInHTMLTemplate(body: html, css: css, basePath: basePath)
            webView.loadHTMLString(fullHTML, baseURL: baseURL)
        }

        if context.coordinator.scrollObserver == nil {
            context.coordinator.setupScrollListener()
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

    private func wrapInHTMLTemplate(body: String, css: String, basePath: String) -> String {
        let mmThemeString = switch appTheme {
            case .dark: "dark"
            case .light: "default"
            case .system: "auto"
        }
        let mermaidScriptTag: String = {
            let js = Self.mermaidJS
            return js.isEmpty ? "" : "<script>\(js)</script>"
        }()
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="default-src 'self'; img-src file: data: https: http:; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
            <base href="\(basePath.replacingOccurrences(of: "\"", with: "&quot;"))">
            <link rel="icon" href="data:,">
            \(mermaidScriptTag)
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
            function observeHeadings() {
                if (typeof observer === 'undefined') return;
                observer.disconnect();
                document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(h => {
                    if (h.id) observer.observe(h);
                });
            }

            function updateContent(newHTML) {
                const container = document.getElementById('content');
                if (container) {
                    container.innerHTML = newHTML;
                    observeHeadings();
                }
            }

            function scrollToAnchor(id) {
                const el = document.getElementById(id);
                if (el) {
                    const offset = el.getBoundingClientRect().top + window.pageYOffset - 20;
                    window.scrollTo({ top: offset, behavior: 'smooth' });
                }
            }

            // Preserve scroll position across updates
            var scrollKey = 'mdviewer_scroll';
            var saved = sessionStorage.getItem(scrollKey);
            if (saved) window.scrollTo(0, parseInt(saved));
            window.addEventListener('scroll', function() {
                sessionStorage.setItem(scrollKey, window.scrollY);
                // Report scroll percentage to Swift for editor sync
                var pct = window.scrollY / (document.body.scrollHeight - window.innerHeight);
                window.webkit.messageHandlers.previewScroll.postMessage(isNaN(pct) ? 0 : pct);
            });

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

            observeHeadings();

            // Mermaid diagram support
            var mmTheme = '\(mmThemeString)';
            if (mmTheme === 'auto') {
                mmTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
            }
            if (typeof mermaid !== 'undefined') {
                // securityLevel 'loose' is safe here — content is from user's own local files, rendered in sandboxed WKWebView
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
            // Re-run after dynamic content updates
            var origUpdate = updateContent;
            updateContent = function(html) { origUpdate(html); requestAnimationFrame(function() { highlightCode(); renderMermaid(); }); };

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
        var lastBasePath: String = ""
        var lastAppTheme: AppTheme?

        weak var webView: WKWebView?
        nonisolated(unsafe) var scrollObserver: (any NSObjectProtocol)?
        nonisolated(unsafe) var editorScrollObserver: (any NSObjectProtocol)?

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
                NotificationCenter.default.post(
                    name: .previewDidScroll,
                    object: commandScope,
                    userInfo: ["percent": percent]
                )
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
            // Sync: editor scroll -> preview
            editorScrollObserver = NotificationCenter.default.addObserver(
                forName: .editorDidScroll,
                object: commandScope,
                queue: .main
            ) { [weak self] notification in
                if let percent = notification.userInfo?["percent"] as? Double {
                    Task { @MainActor in
                        _ = try? await self?.webView?.evaluateJavaScript(
                            "window.scrollTo({top: document.body.scrollHeight * \(percent), behavior: 'auto'})"
                        )
                    }
                }
            }
        }

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = editorScrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
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
    }
}
