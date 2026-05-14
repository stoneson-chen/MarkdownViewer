import Foundation
import SwiftUI

/// Manages file system operations: reading, writing, and building file trees.
@Observable
@MainActor
final class FileService {
    private(set) var rootNode: FileNode?
    private(set) var folderAccessMessage: String?
    /// Set when `loadFolder` finishes building the tree for `currentFolderURL`; `nil` while a load is in flight.
    private(set) var completedFolderLoadURL: URL?
    private(set) var currentFolderURL: URL? {
        didSet { onFolderDidChange?() }
    }

    @ObservationIgnored
    var onFolderDidChange: (() -> Void)?

    /// Cancels stale `onLoadFinished` matching for concurrent `loadFolder` calls.
    @ObservationIgnored
    private var folderLoadEpoch = 0
    @ObservationIgnored
    private var pendingFolderLoadCompletion: (@MainActor () -> Void)?

    /// Open a folder and build a file tree filtered to Markdown files.
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "dialog.chooseFolder", bundle: .appResources)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFolder(at: url)
    }

    /// Load a folder at the given URL into the sidebar.
    func loadFolder(at url: URL, selecting selectedFileURL: URL? = nil, onLoadFinished: (@MainActor () -> Void)? = nil) {
        let folderURL = url.standardized
        let selectedURL = selectedFileURL?.standardized
        currentFolderURL = folderURL
        rootNode = nil
        folderAccessMessage = nil
        completedFolderLoadURL = nil

        folderLoadEpoch += 1
        let epoch = folderLoadEpoch
        pendingFolderLoadCompletion = onLoadFinished

        let applyResult = { @MainActor [folderURL, selectedURL, epoch] (result: Result<FileNode, Error>) in
            guard self.folderLoadEpoch == epoch else { return }
            guard self.currentFolderURL?.standardized == folderURL else { return }
            switch result {
            case .success(let tree):
                self.rootNode = tree
            case .failure(let error):
                self.rootNode = Self.fallbackTree(for: folderURL, selectedFileURL: selectedURL)
                self.folderAccessMessage = String(localized: "sidebar.folderAccessLimited", bundle: .appResources)
                    + " " + error.localizedDescription
            }
            self.completedFolderLoadURL = folderURL
            let completion = self.pendingFolderLoadCompletion
            self.pendingFolderLoadCompletion = nil
            completion?()
        }

        if selectedURL != nil {
            // Security scope from opening a document is started/stopped on the main actor; enumerate on main too.
            Task { @MainActor in
                let result: Result<FileNode, Error> = Result {
                    try Self.buildTree(from: folderURL, depth: 0)
                }
                applyResult(result)
            }
        } else {
            Task.detached { [folderURL] in
                let result: Result<FileNode, Error> = Result {
                    try Self.withSecurityScopedAccess(to: folderURL) {
                        try Self.buildTree(from: folderURL, depth: 0)
                    }
                }

                await MainActor.run {
                    applyResult(result)
                }
            }
        }
    }

    /// Show the current folder name and at least the selected file before async `loadFolder` completes.
    func setPlaceholderTree(for folderURL: URL, selectedFile: URL) {
        let folderURL = folderURL.standardized
        let selected = selectedFile.standardized
        currentFolderURL = folderURL
        folderAccessMessage = nil
        rootNode = Self.fallbackTree(for: folderURL, selectedFileURL: selected)
    }

    /// Read the contents of a file at the given URL.
    func readFile(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Write content to a file at the given URL.
    func writeFile(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Private

    /// Max directory nesting depth for sidebar file tree
    private nonisolated static let maxTreeDepth = 10

    private nonisolated static func buildTree(from url: URL, depth: Int) throws -> FileNode {
        let fm = FileManager.default
        let name = url.lastPathComponent

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return FileNode(id: url, name: name, isDirectory: false, children: nil)
        }

        if isDir.boolValue && depth < Self.maxTreeDepth {
            let contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let children = try contents
                .map { try buildTree(from: $0, depth: depth + 1) }
                .filter { node in
                    // Keep directories that contain .md files, or .md files themselves
                    if node.isDirectory {
                        return node.children?.isEmpty == false
                    }
                    return node.isMarkdown
                }
                .sorted { lhs, rhs in
                    // Directories first, then alphabetical
                    if lhs.isDirectory != rhs.isDirectory {
                        return lhs.isDirectory
                    }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

            return FileNode(id: url, name: name, isDirectory: true, children: children)
        }

        return FileNode(id: url, name: name, isDirectory: false, children: nil)
    }

    private nonisolated static func fallbackTree(for folderURL: URL, selectedFileURL: URL?) -> FileNode {
        guard let selectedFileURL,
              selectedFileURL.deletingLastPathComponent().standardized == folderURL.standardized else {
            return FileNode(id: folderURL, name: folderURL.lastPathComponent, isDirectory: true, children: [])
        }

        let selectedNode = FileNode(
            id: selectedFileURL,
            name: selectedFileURL.lastPathComponent,
            isDirectory: false,
            children: nil
        )
        return FileNode(
            id: folderURL,
            name: folderURL.lastPathComponent,
            isDirectory: true,
            children: selectedNode.isMarkdown ? [selectedNode] : []
        )
    }

    private nonisolated static func withSecurityScopedAccess<T>(
        to url: URL,
        _ body: () throws -> T
    ) rethrows -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }
}
