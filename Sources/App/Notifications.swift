// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import Foundation
import OSLog

final class WindowCommandScope: NSObject {}

enum AppLog {
    static let scroll = Logger(subsystem: "org.chenxx.markdown.viewer", category: "scroll")
}

struct ScrollSyncCommand: Equatable {
    enum Source {
        case editor
        case preview
    }

    let source: Source
    let percent: Double
    let sequence: Int
}

/// Tuning knobs for editor ↔ preview scroll mirroring.
enum ScrollSync {
    /// Ignore sub-pixel percent noise (reduces command spam).
    static let minPercentDelta = 0.004
    /// Coalesce outgoing sync commands to ~60 Hz.
    static let coalesceIntervalMs = 16
    /// Block reverse sync while a remote scroll is being applied.
    static let remoteScrollGuardMs = 250
}

extension Notification.Name {
    // MARK: - Editor Formatting
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatCode = Notification.Name("formatCode")
    static let formatH1 = Notification.Name("formatH1")
    static let formatH2 = Notification.Name("formatH2")
    static let formatH3 = Notification.Name("formatH3")
    static let formatLink = Notification.Name("formatLink")
    static let formatImage = Notification.Name("formatImage")

    // MARK: - View Control
    static let showAboutWindow = Notification.Name("showAboutWindow")

    // MARK: - Navigation & Sync
    static let didDetectHeading = Notification.Name("didDetectHeading")
    static let executeScrollJS = Notification.Name("executeScrollJS")
}
