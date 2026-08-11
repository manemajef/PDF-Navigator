import AppKit

/// Projects a `FileTree` into the native source list.
///
/// Owns no file data. It answers outline-view queries from the tree, turns
/// clicks and selection into the callbacks it was handed, and applies the
/// tree's deltas as row insertions and removals.
final class NavigatorController: NSViewController {
    private let scrollView = NSScrollView()
    private let outlineView = NavigatorOutlineView()
    
    private var rootURL: URL
    private var mode: WorkspaceMode
    /// Fixed for the controller's lifetime; only the mode changes per render.
    private let onSelectPDF: (URL) -> Void
    private let onSelectFolder: (URL) -> Void
    private let onOpenInNewTab: (URL, TabActivation) -> Void
    private let onItemCountChange: (Int?) -> Void
    
    private var tree: FileTree
    
    /// Set while the controller drives the selection itself, so revealing the
    /// session's location does not read back as the user choosing it.
    private var isRevealingSelection = false
    
    init(
        rootURL: URL,
        mode: WorkspaceMode,
        onSelectPDF: @escaping (URL) -> Void,
        onSelectFolder: @escaping (URL) -> Void,
        onOpenInNewTab: @escaping (URL, TabActivation) -> Void,
        onItemCountChange: @escaping (Int?) -> Void
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.mode = mode
        self.onSelectPDF = onSelectPDF
        self.onSelectFolder = onSelectFolder
        self.onOpenInNewTab = onOpenInNewTab
        self.onItemCountChange = onItemCountChange
        tree = FileTree(root: self.rootURL)
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
    
    override func loadView() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        
        outlineView.style = .sourceList
        outlineView.backgroundColor = .clear
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.floatsGroupRows = false
        outlineView.refusesFirstResponder = false
        outlineView.menu = makeContextMenu()
        outlineView.onCommandClick = { [weak self] row in
            self?.openRowInBackgroundTab(row) ?? false
        }
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        scrollView.documentView = outlineView
        view = scrollView
        adoptTree()
    }
    
    func render(rootURL: URL, mode: WorkspaceMode) {
        let rootURL = rootURL.standardizedFileURL
        let rootChanged = self.rootURL != rootURL
        
        self.rootURL = rootURL
        self.mode = mode
        
        loadViewIfNeeded()
        if rootChanged {
            tree = FileTree(root: rootURL)
            adoptTree()
        } else {
            revealSelection()
        }
    }
    
    /// Renders the current tree from scratch and starts watching it.
    ///
    /// The only path that calls `reloadData()`. Every later change arrives as a
    /// delta, which is what preserves expansion and selection.
    private func adoptTree() {
        tree.onChange = { [weak self] deltas in
            self?.apply(deltas)
        }
        tree.startWatching()
        
        outlineView.reloadData()
        outlineView.expandItem(tree.root)
        reportItemCount()
        revealSelection()
    }
    
    private func apply(_ deltas: [FileNode.Delta]) {
        // The tree has already reconciled, so the data source answers with the
        // new state. These calls tell the outline view which rows moved.
        outlineView.beginUpdates()
        for delta in deltas {
            outlineView.removeItems(
                at: delta.removed,
                inParent: delta.parent,
                withAnimation: .effectFade
            )
            outlineView.insertItems(
                at: delta.inserted,
                inParent: delta.parent,
                withAnimation: .effectFade
            )
        }
        outlineView.endUpdates()
        
        reportItemCount()
        revealSelection()
    }
    
    private func reportItemCount() {
        onItemCountChange(tree.root.children.count)
    }
    
    // MARK: - Selection
    
    /// Moves the sidebar selection to wherever the session is pointed.
    private func revealSelection() {
        guard let row = rowForCurrentMode() else {
            outlineView.deselectAll(nil)
            return
        }
        
        isRevealingSelection = true
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        isRevealingSelection = false
        outlineView.scrollRowToVisible(row)
    }
    
    /// The row standing for the current mode, or `nil` when nothing does.
    private func rowForCurrentMode() -> Int? {
        let url: URL
        switch mode {
        case .startPage:
            return nil
        case .library(let folderURL):
            url = folderURL
        case .reading(let pdfURL):
            url = pdfURL
        }
        
        guard url.isDescendantOrSame(of: tree.root.url),
              let node = node(for: url, from: tree.root) else {
            return nil
        }
        
        let row = outlineView.row(forItem: node)
        return row >= 0 ? row : nil
    }
    
    /// The node at `row` or `nil` for Appkit's -1 "no row" sentinel
    private func node(atRow row: Int) -> FileNode? {
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row) as? FileNode
    }
    /// Walks down to `fileURL`, expanding each directory on the way.
    ///
    /// The prefix check runs before any child is touched, so only directories on
    /// the path are scanned.
    private func node(for fileURL: URL, from node: FileNode) -> FileNode? {
        guard fileURL.isDescendantOrSame(of: node.url) else { return nil }
        if node.url == fileURL { return node }
        guard node.isDirectory else { return nil }
        
        outlineView.expandItem(node)
        for child in node.children {
            if let match = self.node(for: fileURL, from: child) {
                return match
            }
        }
        return nil
    }
    
    // MARK: - Commands
    
    /// Command-click on a PDF opens a background tab and leaves selection alone.
    private func openRowInBackgroundTab(_ row: Int) -> Bool {
        guard let node = node(atRow: row), !node.isDirectory else { return false}
        onOpenInNewTab(node.url, .background)
        return true
    }
    
    @objc private func openClickedRowInNewTab(_ sender: Any?) {
        guard let url = contextMenuPDFURL else { return }
        onOpenInNewTab(url, .foreground)
    }
    
    @objc private func openClickedRow(_ sender: Any?) {
        guard let url = contextMenuPDFURL else { return }
        onSelectPDF(url)
    }
    
    @objc private func openClickedRowInDefaultApp(_ sender: Any?) {
        guard let url = contextMenuPDFURL else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func showClickedRowInFinder(_ sender: Any?) {
        guard let url = contextMenuPDFURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - context menu
    private var contextMenuPDFURL: URL? {
        let clickedRow = outlineView.clickedRow
        let row = clickedRow >= 0 ? clickedRow : outlineView.selectedRow
        guard let node = node(atRow: row), !node.isDirectory else { return nil }
        return node.url
    }
    
    private func addItem(to menu: NSMenu, title: String, action: Selector){
        menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
    }
    
    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        addItem(to: menu, title: "Open", action: #selector(openClickedRow(_:)))
        addItem(to: menu, title: "Open in New Tab", action: #selector(openClickedRowInNewTab(_:)))
        menu.addItem(.separator())
        addItem(to: menu, title: "Open in Default App", action: #selector(openClickedRowInDefaultApp(_:)))
        addItem(to: menu, title: "Show in Finder", action: #selector(showClickedRowInFinder(_:)))
        return menu
    }
}

extension NavigatorController: NSOutlineViewDataSource {
    func outlineView(
        _ outlineView: NSOutlineView,
        numberOfChildrenOfItem item: Any?
    ) -> Int {
        switch item {
        case nil: 1
        case let node as FileNode: node.children.count
        default: 0
        }
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        child index: Int,
        ofItem item: Any?
    ) -> Any {
        guard let node = item as? FileNode else { return tree.root }
        return node.children[index]
    }

    /// Answered from the node's kind without reading the directory, so showing
    /// a disclosure triangle costs no scan.
    func outlineView(
        _ outlineView: NSOutlineView,
        isItemExpandable item: Any
    ) -> Bool {
        (item as? FileNode)?.isDirectory == true
    }
}

extension NavigatorController: NSOutlineViewDelegate {
    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let node = item as? FileNode else { return nil }

        let view = outlineView.makeView(
            withIdentifier: NavigatorRowView.identifier,
            owner: self
        ) as? NavigatorRowView ?? NavigatorRowView()
        view.configure(with: node)
        return view
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isRevealingSelection else { return }
        guard let node = node(atRow: outlineView.selectedRow) else { return }

        if node.isDirectory {
            onSelectFolder(node.url)
        } else {
            onSelectPDF(node.url)
        }
    }
}
