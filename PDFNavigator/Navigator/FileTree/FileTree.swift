import Foundation

/// The node tree for one workspace root, kept in sync with disk.
///
/// Owns file data and nothing else — no views, no selection, no AppKit.
/// `NavigatorController` reads it to answer outline-view queries and applies
/// the deltas it publishes.
@MainActor
final class FileTree {
    let root: FileNode

    /// Called after the tree has reconciled itself with disk, carrying the
    /// per-directory changes needed to bring a view in line.
    ///
    /// A delta callback rather than observation: an outline view needs to know
    /// precisely which rows moved. "Something changed" would force a
    /// `reloadData()`, losing expansion state and selection.
    var onChange: (([FileNode.Delta]) -> Void)?

    private var watcher: DirectoryWatcher?

    init(root: URL) {
        self.root = FileNode(url: root, isDirectory: true)
    }

    /// Begins reporting filesystem changes to `onChange`.
    ///
    /// Separate from `init` so a caller can install `onChange` first and not
    /// race the first event.
    func startWatching() {
        watcher = DirectoryWatcher(root: root.url) { [weak self] in
            self?.refresh()
        }
    }

    /// Rescans every loaded directory and publishes what changed.
    ///
    /// Scanning all loaded directories, not just the paths FSEvents named, costs
    /// one `contentsOfDirectory` per opened folder — tens of microseconds each,
    /// against a coalescing latency in the hundreds of milliseconds. It also
    /// stays correct when FSEvents overflows into `MustScanSubDirs` and names
    /// nothing specific.
    func refresh() {
        var deltas: [FileNode.Delta] = []
        collectDeltas(from: root, into: &deltas)
        guard !deltas.isEmpty else { return }
        onChange?(deltas)
    }

    /// Walks top-down so a removed directory's children are never visited.
    /// A delta for a detached node would target a row that no longer exists.
    private func collectDeltas(
        from node: FileNode,
        into deltas: inout [FileNode.Delta]
    ) {
        if let delta = node.reload() {
            deltas.append(delta)
        }
        for child in node.loadedChildren ?? [] where child.isDirectory {
            collectDeltas(from: child, into: &deltas)
        }
    }
}
