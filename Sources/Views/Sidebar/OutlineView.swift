// * Copyright © 2026  CHENXX & CHENXX.ORG. All rights reserved.
// * CHENXX.ORG 版权所有，全球范围内保留所有权利。
// * 项目名称：MarkdownViewer（墨阅）
// * 开发人员：Chen Xinxing（陈新兴）
// * 创建日期：2026
// *
// * Licensed under the MIT License.
// * See the LICENSE file in the project root for full license text.

import SwiftUI

/// A view that displays the table of contents (TOC) for the current document.
struct OutlineView: View {
    let headings: [MarkdownParser.Heading]
    let activeHeadingID: String?
    let onSelect: (MarkdownParser.Heading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if headings.isEmpty {
                emptyState
            } else {
                outlineList
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)
    }

    private var header: some View {
        HStack {
            Label(String(localized: "outline.title", bundle: .appResources), systemImage: "list.bullet.indent")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var outlineList: some View {
        List(headings) { heading in
            let isActive = heading.anchorID == activeHeadingID
            
            HStack(spacing: 8) {
                headingIcon(for: heading.level)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                
                Text(heading.text)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? Color.accentColor : .primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(heading)
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.alignleft")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text(String(localized: "outline.empty.title", bundle: .appResources))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(localized: "outline.empty.description", bundle: .appResources))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func headingIcon(for level: Int) -> some View {
        switch level {
        case 1: Image(systemName: "h.square.fill")
        case 2: Image(systemName: "h.square")
        case 3: Image(systemName: "number")
        default: Image(systemName: "circle.fill").font(.system(size: 4))
        }
    }
}
