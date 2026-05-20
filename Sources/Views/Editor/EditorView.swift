// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI
import AppKit

private enum EditorFormatActions {
    static let wrap: [(Notification.Name, String, String, String.LocalizationValue)] = [
        (.formatBold, "**", "**", "editor.placeholder.bold"),
        (.formatItalic, "*", "*", "editor.placeholder.italic"),
        (.formatCode, "`", "`", "editor.placeholder.code"),
        (.formatLink, "[", "](url)", "editor.placeholder.link"),
        (.formatImage, "![", "](url)", "editor.placeholder.image"),
    ]
}

/// The Markdown source editor pane, wrapping NSTextView for performance.
struct EditorView: View {
    @Binding var text: String
    let commandScope: WindowCommandScope
    let scrollSyncCommand: ScrollSyncCommand?
    let onScroll: (Double) -> Void

    var body: some View {
        MarkdownTextEditor(
            text: $text,
            commandScope: commandScope,
            scrollSyncCommand: scrollSyncCommand,
            onScroll: onScroll
        )
            .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - NSTextView Wrapper (better perf than SwiftUI TextEditor for large docs)

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let commandScope: WindowCommandScope
    let scrollSyncCommand: ScrollSyncCommand?
    let onScroll: (Double) -> Void
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
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.setupScrollSync()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        // Only update if text actually changed externally (avoid feedback loop)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = clampedRanges(selectedRanges, maxLength: (text as NSString).length)
        }

        if let scrollSyncCommand {
            context.coordinator.applyScrollCommandIfNeeded(scrollSyncCommand)
        }
    }

    private func clampedRanges(_ ranges: [NSValue], maxLength: Int) -> [NSValue] {
        ranges.map { value in
            let range = value.rangeValue
            let location = min(range.location, maxLength)
            let length = min(range.length, maxLength - location)
            return NSValue(range: NSRange(location: location, length: length))
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        private nonisolated(unsafe) var notificationObservers: [any NSObjectProtocol] = []
        private var isApplyingRemoteScroll = false
        private var remoteScrollResetTask: Task<Void, Never>?
        private var lastAppliedScrollSequence: Int?
        private var lastReportedScrollPercent: Double = -1

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
            super.init()
            registerFormatNotifications()
        }

        deinit {
            remoteScrollResetTask?.cancel()
            notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func setupScrollSync() {
            guard let scrollView = scrollView else { return }
            // `didLiveScroll` alone is enough; avoid duplicate `boundsDidChange` events.
            notificationObservers.append(
                NotificationCenter.default.addObserver(
                    forName: NSScrollView.didLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in self?.editorDidScroll() }
                }
            )
        }

        private func editorDidScroll() {
            guard !isApplyingRemoteScroll, let scrollView = scrollView, let textView = textView else { return }
            let visibleRect = scrollView.contentView.bounds
            let totalHeight = documentHeight(for: textView)
            let scrollableHeight = totalHeight - visibleRect.height
            guard scrollableHeight > 0 else { return }
            let percent = min(1.0, max(0.0, visibleRect.minY / scrollableHeight))
            guard abs(percent - lastReportedScrollPercent) >= ScrollSync.minPercentDelta else { return }
            lastReportedScrollPercent = percent
            parent.onScroll(percent)
        }

        func applyScrollCommandIfNeeded(_ command: ScrollSyncCommand) {
            guard command.source == .preview else { return }
            guard lastAppliedScrollSequence != command.sequence else { return }
            lastAppliedScrollSequence = command.sequence
            AppLog.scroll.debug("EditorView apply remote scroll percent=\(command.percent, privacy: .public) sequence=\(command.sequence, privacy: .public)")
            applyRemoteScroll(command.percent)
        }

        private func applyRemoteScroll(_ percent: Double) {
            guard let scrollView = scrollView, let textView = textView else { return }
            let clampedPercent = min(1.0, max(0.0, percent))
            guard abs(clampedPercent - lastReportedScrollPercent) >= ScrollSync.minPercentDelta else { return }

            let totalHeight = documentHeight(for: textView)
            let visibleHeight = scrollView.contentView.bounds.height
            let scrollableHeight = max(0, totalHeight - visibleHeight)
            let targetY = clampedPercent * scrollableHeight
            isApplyingRemoteScroll = true
            lastReportedScrollPercent = clampedPercent
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            scheduleRemoteScrollReset()
        }

        private func documentHeight(for textView: NSTextView) -> CGFloat {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return textView.bounds.height
            }

            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height + textView.textContainerInset.height * 2
            return max(textView.bounds.height, usedHeight)
        }

        private func scheduleRemoteScrollReset() {
            remoteScrollResetTask?.cancel()
            remoteScrollResetTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(ScrollSync.remoteScrollGuardMs))
                self?.isApplyingRemoteScroll = false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        // MARK: - Format Notification Handling

        private func registerFormatNotifications() {
            let center = NotificationCenter.default

            for (name, prefix, suffix, placeholderKey) in EditorFormatActions.wrap {
                notificationObservers.append(
                    center.addObserver(forName: name, object: parent.commandScope, queue: .main) { [weak self] _ in
                        let placeholder = String.appLocalized(placeholderKey)
                        Task { @MainActor in
                            self?.wrapSelection(prefix: prefix, suffix: suffix, placeholder: placeholder)
                        }
                    }
                )
            }

            let headingPrefixes: [(Notification.Name, String)] = [
                (.formatH1, "# "),
                (.formatH2, "## "),
                (.formatH3, "### "),
            ]
            for (name, prefix) in headingPrefixes {
                notificationObservers.append(
                    center.addObserver(forName: name, object: parent.commandScope, queue: .main) { [weak self] _ in
                        Task { @MainActor in self?.prefixLine(prefix: prefix) }
                    }
                )
            }
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
