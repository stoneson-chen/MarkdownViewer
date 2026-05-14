import SwiftUI

/// File tree sidebar for browsing Markdown files in a folder.
struct SidebarView: View {
    @Bindable var fileService: FileService
    @Binding var selectedFileURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with open folder button
            HStack {
                Text(fileService.currentFolderURL?.lastPathComponent ?? String(localized: "sidebar.title", bundle: .appResources))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    fileService.openFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "sidebar.openFolder", bundle: .appResources))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // File tree
            if let root = fileService.rootNode {
                List(selection: $selectedFileURL) {
                    if let children = root.children {
                        ForEach(children) { child in
                            FileTreeNode(node: child)
                        }
                    } else {
                        FileTreeNode(node: root)
                    }
                }
                .listStyle(.sidebar)
            } else if fileService.currentFolderURL != nil {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载中…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text(String(localized: "sidebar.noFolder", bundle: .appResources))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(String(localized: "sidebar.openFolderButton", bundle: .appResources)) {
                fileService.openFolder()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recursive File Tree Node

private struct FileTreeNode: View {
    let node: FileNode

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeNode(node: child)
                    }
                }
            } label: {
                Label(node.name, systemImage: node.iconName)
                    .font(.system(size: 13))
            }
        } else {
            Label(node.name, systemImage: node.iconName)
                .font(.system(size: 13))
                .tag(node.id)
        }
    }
}
