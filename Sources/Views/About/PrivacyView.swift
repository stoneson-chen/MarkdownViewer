// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI

/// Privacy policy sheet displayed from the About window.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    private var privacyContent: AttributedString {
        let markdown = String.appLocalized("privacy.content")
        return (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        )) ?? AttributedString(markdown)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String.appLocalized("privacy.title"))
                    .font(.headline)
                Spacer()
                Button(String.appLocalized("privacy.done")) { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            ScrollView {
                Text(privacyContent)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 480, height: 400)
    }
}
