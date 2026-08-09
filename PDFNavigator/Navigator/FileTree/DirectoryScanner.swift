import Foundation

/// Filesystem enumeration for the navigator: PDFs and directories, sorted.
///
/// `nonisolated` because it holds no state. Under the project's default
/// main-actor isolation, `isOrderedBefore` would otherwise be actor-bound and
/// could not be handed to `sorted(by:)`.
nonisolated enum DirectoryScanner {
    struct Item {
        let url: URL
        let isDirectory: Bool

        var name: String { url.lastPathComponent }
    }

    /// Enumerates one directory, without recursing.
    ///
    /// Synchronous by design: `contentsOfDirectory` prefetches the resource
    /// values it is asked for, so the loop below reads a cache instead of
    /// issuing a syscall per entry. A few hundred local entries cost tens of
    /// microseconds, which is what lets `FileNode` scan during an outline-view
    /// query.
    ///
    /// Watch out on network volumes and spinning disks, where this blocks the
    /// main thread. `FileNode.children` is the single place to make
    /// asynchronous if that arises, and it would need a placeholder row.
    static func items(in directory: URL) -> [Item] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var items: [Item] = []
        items.reserveCapacity(urls.count)

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true else {
                continue
            }

            if values.isDirectory == true {
                items.append(Item(url: url.standardizedFileURL, isDirectory: true))
            } else if values.isRegularFile == true,
                      url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
                items.append(Item(url: url.standardizedFileURL, isDirectory: false))
            }
        }

        return items.sorted(by: isOrderedBefore)
    }

    /// Directories first, then localized name order.
    ///
    /// `FileNode.reload()` depends on this being the only ordering the
    /// navigator ever applies: its diff assumes the surviving nodes appear in
    /// the same relative order before and after a rescan.
    private static func isOrderedBefore(_ lhs: Item, _ rhs: Item) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
