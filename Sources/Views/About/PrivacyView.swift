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
/// Uses native SwiftUI AttributedString markdown rendering — no WebView overhead.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    private let privacyMD = """
    # 隐私政策 (Privacy Policy)

    **墨阅 (MarkdownViewer)** 是一款极简的本地 Markdown 编辑工具。我们高度重视用户的隐私保护。

    ## 数据收集声明

    **墨阅不收集任何个人数据。**

    - **不采集信息**：应用不要求用户注册、登录，也不采集任何姓名、邮箱、位置等个人信息。
    - **本地处理**：所有的 Markdown 解析、渲染和存储均在您的设备本地完成，数据不会上传到任何服务器。
    - **无追踪器**：应用内不包含任何第三方 SDK、广告插件或分析统计工具。
    - **文件访问**：应用仅在您明确通过文件选择器或拖拽授权的情况下，访问特定的文件或文件夹。

    ## 联系我们

    如果您对本隐私政策有任何疑问，请通过 GitHub Issues 与我们联系。

    ---
    *最后更新：2026-05-13*
    """

    private var privacyContent: AttributedString {
        (try? AttributedString(
            markdown: privacyMD,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        )) ?? AttributedString(privacyMD)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("隐私政策")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
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
