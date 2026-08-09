import Foundation

/// One directory or PDF in the navigator tree.
///
/// `NSOutlineView` tracks rows by object identity, so a node must remain the
/// same object for as long as its path exists on disk. Replacing a node that
/// still exists collapses its expansion state and drops the selection.
final class FileNode: NSObject {
    /// One directory's worth of change.
    ///
    /// The two index sets are in different coordinate spaces: `removed` indexes
    /// the children as they were before the rescan, `inserted` as they are
    /// after. That is what `removeItems(at:inParent:)` followed by
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
    /// Scanning during the data-source query keeps `numberOfChildrenOfItem`
    /// truthful the first time AppKit asks, so a folder does not render empty
    /// and then repopulate.
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
    /// Walking the tree with this avoids scanning directories nothing has asked
    /// to see.
    var loadedChildren: [FileNode]? { loaded }

    private convenience init(item: DirectoryScanner.Item) {
        self.init(url: item.url, isDirectory: item.isDirectory)
    }

    /// Rescans this directory and reconciles the in-memory children with disk.
    ///
    /// Surviving paths keep their existing node, and with it their expansion
    /// state and loaded subtree. Returns `nil` when this node was never loaded,
    /// or when disk and memory already agree.
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
    /// Kind is part of the key: a PDF replaced by a folder of the same name is a
    /// different row with a different disclosure affordance, so it counts as a
    /// removal plus an insertion.
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
