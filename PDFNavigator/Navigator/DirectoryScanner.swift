import Foundation

/// Filesystem enumeration for the navigator: PDFs and directories, sorted.
///
/// `nonisolated` because this is a pure function of the filesystem with no
/// state of its own. Without it the project's default main-actor isolation
/// would infer `isOrderedBefore` as main-actor-bound and then complain about
/// handing it to `sorted(by:)`.
nonisolated enum DirectoryScanner {
    struct Item {
        let url: URL
        let isDirectory: Bool

        var name: String { url.lastPathComponent }
    }

    /// Enumerates one directory, without recursing.
    ///
    /// This is deliberately synchronous. `contentsOfDirectory` prefetches the
    /// resource values it is asked for, so the loop below reads a cache instead
    /// of issuing a syscall per entry; on a local volume a few hundred entries
    /// cost tens of microseconds, well under one frame. That is what lets
    /// `NavigatorNode` scan lazily during an outline-view query and still report
    /// a true child count on the first ask.
    ///
    /// A network volume or a spinning disk would hitch here. `NavigatorNode`'s
    /// `children` getter is the single place that would become asynchronous if
    /// that ever matters, and it would need a placeholder row to stay honest.
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
    /// `NavigatorNode.reload()` depends on this being the only ordering the
    /// navigator ever applies: its diff assumes the surviving nodes appear in
    /// the same relative order before and after a rescan.
    private static func isOrderedBefore(_ lhs: Item, _ rhs: Item) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
