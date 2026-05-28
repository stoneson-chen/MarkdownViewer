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
    let documentKey: String
    let onSelect: (MarkdownParser.Heading) -> Void

    @State private var collapsedIDs: Set<String> = []

    private var tree: [OutlineNode] {
        OutlineTreeBuilder.build(from: headings)
    }

    private var rootLevel: Int {
        headings.map(\.level).min() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if headings.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(tree) { node in
                        OutlineNodeView(
                            node: node,
                            rootLevel: rootLevel,
                            activeHeadingID: activeHeadingID,
                            collapsedIDs: $collapsedIDs,
                            onSelect: onSelect
                        )
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)
        .onChange(of: documentKey) { _, _ in
            collapsedIDs.removeAll()
        }
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
}

// MARK: - Outline Tree

private struct OutlineNode: Identifiable {
    let heading: MarkdownParser.Heading
    let children: [OutlineNode]

    var id: String { heading.id }
}

private enum OutlineTreeBuilder {
    static func build(from headings: [MarkdownParser.Heading]) -> [OutlineNode] {
        guard !headings.isEmpty else { return [] }

        var index = 0

        func collectChildren(parentLevel: Int) -> [OutlineNode] {
            var nodes: [OutlineNode] = []
            while index < headings.count {
                let heading = headings[index]
                if heading.level <= parentLevel { break }
                index += 1
                let children = collectChildren(parentLevel: heading.level)
                nodes.append(OutlineNode(heading: heading, children: children))
            }
            return nodes
        }

        var roots: [OutlineNode] = []
        while index < headings.count {
            let heading = headings[index]
            index += 1
            let children = collectChildren(parentLevel: heading.level)
            roots.append(OutlineNode(heading: heading, children: children))
        }
        return roots
    }
}

private struct OutlineNodeView: View {
    let node: OutlineNode
    let rootLevel: Int
    let activeHeadingID: String?
    @Binding var collapsedIDs: Set<String>
    let onSelect: (MarkdownParser.Heading) -> Void

    var body: some View {
        if node.children.isEmpty {
            OutlineHeadingRow(
                heading: node.heading,
                rootLevel: rootLevel,
                activeHeadingID: activeHeadingID,
                onSelect: onSelect
            )
        } else {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(node.children) { child in
                    OutlineNodeView(
                        node: child,
                        rootLevel: rootLevel,
                        activeHeadingID: activeHeadingID,
                        collapsedIDs: $collapsedIDs,
                        onSelect: onSelect
                    )
                }
            } label: {
                OutlineHeadingRow(
                    heading: node.heading,
                    rootLevel: rootLevel,
                    activeHeadingID: activeHeadingID,
                    onSelect: onSelect
                )
            }
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { !collapsedIDs.contains(node.id) },
            set: { expanded in
                if expanded {
                    collapsedIDs.remove(node.id)
                } else {
                    collapsedIDs.insert(node.id)
                }
            }
        )
    }
}

private struct OutlineHeadingRow: View {
    let heading: MarkdownParser.Heading
    let rootLevel: Int
    let activeHeadingID: String?
    let onSelect: (MarkdownParser.Heading) -> Void

    var body: some View {
        Text(attributedTitle)
            .font(.system(size: 13, weight: rowWeight))
            .foregroundStyle(isActive ? Color.accentColor : .primary)
            .padding(.leading, leadingInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 8))
            .onTapGesture {
                onSelect(heading)
            }
    }

    private var leadingInset: CGFloat {
        CGFloat(max(0, heading.level - rootLevel)) * 14
    }

    private var isActive: Bool {
        heading.anchorID == activeHeadingID
    }

    private var rowWeight: Font.Weight {
        if isActive || heading.level == rootLevel {
            return .semibold
        }
        return .regular
    }

    private var attributedTitle: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        if let title = try? AttributedString(markdown: heading.markdownText, options: options) {
            return title
        }

        return AttributedString(heading.text)
    }
}
