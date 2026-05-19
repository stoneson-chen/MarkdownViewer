// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import Foundation

extension Bundle {
    /// A helper to find the localization bundle, falling back to main if the SPM module bundle isn't available or doesn't contain strings.
    static var appResources: Bundle {
        #if DEBUG
        return Bundle.module
        #else
        // SwiftPM executable resource accessors look beside Bundle.main.bundleURL in packaged apps.
        if let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("MarkdownViewer_MarkdownViewer.bundle")) {
            return bundle
        }
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("MarkdownViewer_MarkdownViewer.bundle"),
           let bundle = Bundle(url: bundleURL) {
            return bundle
        }
        // Fallback to main bundle (where we also copy .lproj files in package_app.sh)
        return Bundle.main
        #endif
    }
}

extension String {
    /// Localized string from `Localizable.strings` in the app resource bundle.
    static func appLocalized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .appResources)
    }
}
