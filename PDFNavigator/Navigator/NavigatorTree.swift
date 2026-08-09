import Foundation

/// The navigator's model layer: the node tree for one workspace root, kept in
/// sync with disk.
///
/// This type owns file data and nothing else — no views, no selection, no
/// AppKit. `NavigatorController` reads it to answer outline-view queries and
/// applies the deltas it publishes. Keeping the two apart is what makes the
/// controller a projection rather than a second source of truth.
@MainActor
final class NavigatorTree {
    let root: NavigatorNode

    /// Called after the tree has already reconciled itself with disk, with the
    /// per-directory changes needed to bring a view in line.
    ///
    /// This is deliberately a delta callback rather than `@Observable`.
    /// Observation reports *that* something changed, which for an outline view
    /// means falling back to `reloadData()` — losing expansion state, selection,
    /// and any animation. The whole point of reconciling in place is to know
    /// precisely which rows moved.
    var onChange: (([NavigatorNode.Delta]) -> Void)?

    private var watcher: DirectoryWatcher?

    init(root: URL) {
        self.root = NavigatorNode(url: root, isDirectory: true)
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
    /// Rescanning all loaded directories rather than only the paths FSEvents
    /// named costs a `contentsOfDirectory` per folder the user has opened — tens
    /// of microseconds each, against a coalescing latency measured in hundreds
    /// of milliseconds. It also stays correct when FSEvents coalesces an
    /// overflow into `MustScanSubDirs` and tells us nothing specific.
    func refresh() {
        var deltas: [NavigatorNode.Delta] = []
        collectDeltas(from: root, into: &deltas)
        guard !deltas.isEmpty else { return }
        onChange?(deltas)
    }

    /// Walks top-down so a removed directory's own children are never visited:
    /// once a node is gone from its parent it is gone from the outline view too,
    /// and reporting a delta for it would target a row that no longer exists.
    private func collectDeltas(
        from node: NavigatorNode,
        into deltas: inout [NavigatorNode.Delta]
    ) {
        if let delta = node.reload() {
            deltas.append(delta)
        }
        for child in node.loadedChildren ?? [] where child.isDirectory {
            collectDeltas(from: child, into: &deltas)
        }
    }
}
