import Foundation
import CryptoKit

/// Persists security-scoped bookmarks for folders the user granted via `NSOpenPanel`, so listing siblings works
/// after reopening files in the same directory (App Sandbox + `com.apple.security.files.bookmarks.app-scope`).
enum SidebarFolderBookmarkStore {
    private nonisolated static func storageKey(forDirectoryPath path: String) -> String {
        let digest = SHA256.hash(data: Data(path.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "sidebarSSFolder." + hex
    }

    /// Call while `folderURL` has an active security scope (e.g. immediately after `NSOpenPanel` returns).
    nonisolated static func saveBookmark(forContainingDirectory folderURL: URL) throws {
        let path = folderURL.standardized.path(percentEncoded: false)
        let data = try folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: storageKey(forDirectoryPath: path))
    }

    /// Returns a resolved folder URL with security scope if we have a stored bookmark for this directory path.
    nonisolated static func resolvedScopedDirectory(matching folderURL: URL) -> URL? {
        let path = folderURL.standardized.path(percentEncoded: false)
        guard let data = UserDefaults.standard.data(forKey: storageKey(forDirectoryPath: path)) else { return nil }
        var stale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            UserDefaults.standard.removeObject(forKey: storageKey(forDirectoryPath: path))
            return nil
        }
        if stale {
            UserDefaults.standard.removeObject(forKey: storageKey(forDirectoryPath: path))
            return nil
        }
        let r = resolved.standardized
        guard r.path(percentEncoded: false) == path else { return nil }
        return r
    }
}
