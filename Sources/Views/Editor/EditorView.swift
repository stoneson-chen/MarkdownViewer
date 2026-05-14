import SwiftUI
import AppKit

/// The Markdown source editor pane, wrapping NSTextView for performance.
struct EditorView: View {
    @Binding var text: String
    let commandScope: WindowCommandScope

    var body: some View {
        MarkdownTextEditor(text: $text, commandScope: commandScope)
            .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - NSTextView Wrapper (better perf than SwiftUI TextEditor for large docs)

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let commandScope: WindowCommandScope
    @AppStorage("editorFontSize") private var fontSize: Double = 14

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Editor appearance
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Layout
        textView.textContainerInset = NSSize(width: 20, height: 16)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        // Line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        textView.defaultParagraphStyle = paragraphStyle

        textView.delegate = context.coordinator
        textView.string = text

        // Scroll view appearance
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.setupScrollSync()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text actually changed externally (avoid feedback loop)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        private nonisolated(unsafe) var notificationObservers: [any NSObjectProtocol] = []
        private var isSyncing = false

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
            super.init()
            registerFormatNotifications()
        }

        deinit {
            notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func setupScrollSync() {
            guard let scrollView = scrollView else { return }
            // Observe editor scroll to notify preview
            notificationObservers.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in self?.editorDidScroll() }
                }
            )
            // Observe preview scroll to sync editor
            notificationObservers.append(
                NotificationCenter.default.addObserver(
                    forName: .previewDidScroll,
                    object: parent.commandScope,
                    queue: .main
                ) { [weak self] notification in
                    let percent = notification.userInfo?["percent"] as? Double ?? 0
                    Task { @MainActor in self?.syncToPreview(percent) }
                }
            )
        }

        private func editorDidScroll() {
            guard !isSyncing, let scrollView = scrollView, let textView = textView else { return }
            let visibleRect = scrollView.contentView.bounds
            let totalHeight = textView.bounds.height
            guard totalHeight > 0 else { return }
            let percent = min(1.0, max(0.0, visibleRect.minY / (totalHeight - visibleRect.height)))
            isSyncing = true
            NotificationCenter.default.post(
                name: .editorDidScroll,
                object: parent.commandScope,
                userInfo: ["percent": percent]
            )
            DispatchQueue.main.async { [weak self] in self?.isSyncing = false }
        }

        private func syncToPreview(_ percent: Double) {
            guard !isSyncing, let scrollView = scrollView, let textView = textView else { return }
            let totalHeight = textView.bounds.height
            let visibleHeight = scrollView.contentView.bounds.height
            let targetY = percent * (totalHeight - visibleHeight)
            isSyncing = true
            textView.scroll(NSPoint(x: 0, y: targetY))
            DispatchQueue.main.async { [weak self] in self?.isSyncing = false }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        // MARK: - Format Notification Handling

        private func registerFormatNotifications() {
            let center = NotificationCenter.default

            notificationObservers.append(
                center.addObserver(forName: .formatBold, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.wrapSelection(prefix: "**", suffix: "**", placeholder: "粗体文本") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatItalic, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.wrapSelection(prefix: "*", suffix: "*", placeholder: "斜体文本") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatCode, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.wrapSelection(prefix: "`", suffix: "`", placeholder: "代码") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatH1, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.prefixLine(prefix: "# ") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatH2, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.prefixLine(prefix: "## ") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatH3, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.prefixLine(prefix: "### ") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatLink, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.wrapSelection(prefix: "[", suffix: "](url)", placeholder: "链接文本") }
                }
            )
            notificationObservers.append(
                center.addObserver(forName: .formatImage, object: parent.commandScope, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.wrapSelection(prefix: "![", suffix: "](url)", placeholder: "图片描述") }
                }
            )
        }

        // MARK: - Text Manipulation

        /// Wrap the selected text (or insert placeholder) with prefix and suffix.
        private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
            guard let textView = textView else { return }

            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0 {
                let selectedText = (textView.string as NSString).substring(with: selectedRange)
                let wrapped = "\(prefix)\(selectedText)\(suffix)"

                textView.undoManager?.beginUndoGrouping()
                textView.insertText(wrapped, replacementRange: selectedRange)
                let newRange = NSRange(location: selectedRange.location + prefix.count, length: selectedText.count)
                textView.setSelectedRange(newRange)
                textView.undoManager?.endUndoGrouping()
            } else {
                textView.undoManager?.beginUndoGrouping()
                textView.insertText("\(prefix)\(placeholder)\(suffix)", replacementRange: selectedRange)
                let placeholderRange = NSRange(
                    location: selectedRange.location + prefix.count,
                    length: placeholder.count
                )
                textView.setSelectedRange(placeholderRange)
                textView.undoManager?.endUndoGrouping()
            }

            textView.didChangeText()
        }

        /// Prefix the current line with the given string.
        private func prefixLine(prefix: String) {
            guard let textView = textView else { return }

            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let lineRange = nsString.lineRange(for: selectedRange)

            textView.undoManager?.beginUndoGrouping()
            textView.insertText(prefix, replacementRange: NSRange(location: lineRange.location, length: 0))
            textView.undoManager?.endUndoGrouping()

            textView.didChangeText()
        }
    }
}
