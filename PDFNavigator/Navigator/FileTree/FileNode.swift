import Foundation

/// One directory or PDF in the navigator tree.
///
/// `NSOutlineView` tracks rows by object identity, so a node must remain the
/// same object for as long as its path exists on disk. That is why `reload()`
/// reconciles in place and reuses surviving nodes rather than rebuilding the
/// array: identity here plays the role a `key` plays in a React list, and
/// throwing it away would collapse every expanded folder on every filesystem
/// event.
final class FileNode: NSObject {
    /// One directory's worth of change, in the form `NSOutlineView` wants.
    ///
    /// `removed` indexes the children as they were before the rescan and
    /// `inserted` indexes them as they are after, which is exactly the
    /// convention `removeItems(at:inParent:)` followed by
    /// `insertItems(at:inParent:)` expects inside one update block.
    struct Delta {
        let parent: FileNode
        let removed: IndexSet
        let inserted: IndexSet
    }

    let url: URL
    let isDirectory: Bool

    private var loaded: [FileNode]?

    init(url: URL, isDirectory: Bool) {
        self.url = url.standardizedFileURL
        self.isDirectory = isDirectory
    }

    var name: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    /// Children, scanned on first access.
    ///
    /// Scanning here rather than in response to an expansion notification is
    /// what keeps `numberOfChildrenOfItem` truthful the first time AppKit asks,
    /// so a folder never renders empty and then repopulates a frame later.
    var children: [FileNode] {
        if let loaded { return loaded }

        let scanned = isDirectory
            ? DirectoryScanner.items(in: url).map { FileNode(item: $0) }
            : []
        loaded = scanned
        return scanned
    }

    /// Children already in memory, or `nil` if this node has never been opened.
    ///
    /// Callers that walk the tree use this instead of `children` so that
    /// visiting a node does not force a scan of a directory nothing has asked
    /// to see yet.
    var loadedChildren: [FileNode]? { loaded }

    private convenience init(item: DirectoryScanner.Item) {
        self.init(url: item.url, isDirectory: item.isDirectory)
    }

    /// Rescans this directory and reconciles the in-memory children with disk.
    ///
    /// Returns `nil` when nothing on screen depends on this node yet (it was
    /// never loaded) or when disk and memory already agree. Paths that survived
    /// keep their existing node, and therefore their expansion state and their
    /// loaded subtree.
    func reload() -> Delta? {
        guard isDirectory, let current = loaded else { return nil }

        let scanned = DirectoryScanner.items(in: url)
        let scannedKeys = Set(scanned.map { Key(item: $0) })

        var survivors: [Key: FileNode] = [:]
        var removed = IndexSet()
        for (index, node) in current.enumerated() {
            let key = Key(node: node)
            if scannedKeys.contains(key) {
                survivors[key] = node
            } else {
                removed.insert(index)
            }
        }

        var inserted = IndexSet()
        var next: [FileNode] = []
        next.reserveCapacity(scanned.count)
        for (index, item) in scanned.enumerated() {
            if let survivor = survivors[Key(item: item)] {
                next.append(survivor)
            } else {
                next.append(FileNode(item: item))
                inserted.insert(index)
            }
        }

        guard !removed.isEmpty || !inserted.isEmpty else { return nil }

        loaded = next
        return Delta(parent: self, removed: removed, inserted: inserted)
    }

    /// Identity for reconciliation.
    ///
    /// A path that changed kind — a PDF replaced by a folder of the same name —
    /// is a different row with a different disclosure affordance, so it counts
    /// as a removal plus an insertion rather than a survivor.
    private struct Key: Hashable {
        let url: URL
        let isDirectory: Bool

        init(node: FileNode) {
            url = node.url
            isDirectory = node.isDirectory
        }

        init(item: DirectoryScanner.Item) {
            url = item.url
            isDirectory = item.isDirectory
        }
    }
}
