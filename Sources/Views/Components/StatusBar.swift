// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI

/// Bottom status bar showing document statistics and mode info.
struct StatusBar: View {
    @Bindable var viewModel: DocumentViewModel

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "list.number")
                Text("\(viewModel.lineCount) \(String(localized: "status.lines", bundle: .appResources))")
            }
            
            HStack(spacing: 4) {
                Text("\(String(localized: "status.totalCharacters", bundle: .appResources))\(viewModel.characterCount)")
            }

            Spacer()

            // Current mode indicator
            HStack(spacing: 4) {
                Image(systemName: viewModel.isEditing ? "pencil.line" : "eye.fill")
                    .font(.system(size: 10))
                Text(String(localized: viewModel.isEditing ? "status.edit" : "status.preview", bundle: .appResources))
            }

            if viewModel.isEditing {
                Text(viewModel.splitOrientation.displayName)
            }

            Text("UTF-8")
            Text("Markdown")

            // Dirty indicator
            Circle()
                .fill(viewModel.isDirty ? .orange : .green)
                .frame(width: 6, height: 6)
                .help(String(localized: viewModel.isDirty ? "status.unsaved" : "status.saved", bundle: .appResources))
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
