// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import Foundation

final class WindowCommandScope: NSObject {}

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
    static let scrollToHeading = Notification.Name("scrollToHeading")
    static let didDetectHeading = Notification.Name("didDetectHeading")
    static let executeScrollJS = Notification.Name("executeScrollJS")
    static let editorDidScroll = Notification.Name("editorDidScroll")
    static let previewDidScroll = Notification.Name("previewDidScroll")
}
