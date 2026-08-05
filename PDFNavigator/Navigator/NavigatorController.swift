import AppKit

/// The native outline implementation owned by `SidebarController`.
final class NavigatorController: NSViewController {
    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()

    private var rootURL: URL
    private var selectedPDFURL: URL?
    private var onSelectPDF: (URL) -> Void
    private var onOpenInNewTab: (URL, TabActivation) -> Void
    private var onItemCountChange: (Int?) -> Void

    private var rootNode: NavigatorNode?
    private var loadingNodes: Set<URL> = []

    init(
        rootURL: URL,
        selectedPDFURL: URL?,
        onSelectPDF: @escaping (URL) -> Void,
        onOpenInNewTab: @escaping (URL, TabActivation) -> Void,
        onItemCountChange: @escaping (Int?) -> Void
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.selectedPDFURL = selectedPDFURL?.standardizedFileURL
        self.onSelectPDF = onSelectPDF
        self.onOpenInNewTab = onOpenInNewTab
        self.onItemCountChange = onItemCountChange
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
        outlineView.target = self
        outlineView.action = #selector(rowClicked)
        outlineView.indentationPerLevel = 14
        outlineView.refusesFirstResponder = false
        outlineView.menu = makeContextMenu()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        scrollView.documentView = outlineView

        view = scrollView
        reloadTree()
    }

    func update(
        rootURL: URL,
        selectedPDFURL: URL?,
        onSelectPDF: @escaping (URL) -> Void,
        onOpenInNewTab: @escaping (URL, TabActivation) -> Void,
        onItemCountChange: @escaping (Int?) -> Void
    ) {
        let rootURL = rootURL.standardizedFileURL
        let rootChanged = self.rootURL != rootURL

        self.rootURL = rootURL
        self.selectedPDFURL = selectedPDFURL?.standardizedFileURL
        self.onSelectPDF = onSelectPDF
        self.onOpenInNewTab = onOpenInNewTab
        self.onItemCountChange = onItemCountChange

        loadViewIfNeeded()
        if rootChanged {
            reloadTree()
        } else {
            revealSelectedPDF()
        }
    }

    private func reloadTree() {
        loadingNodes.removeAll()
        rootNode = NavigatorNode(url: rootURL, isDirectory: true)
        outlineView.reloadData()

        guard let rootNode else { return }
        loadChildrenIfNeeded(for: rootNode) { [weak self] in
            guard let self else { return }
            outlineView.reloadData()
            onItemCountChange(rootNode.children?.count)
            revealSelectedPDF()
        }
    }

    private func loadChildrenIfNeeded(
        for node: NavigatorNode,
        completion: (() -> Void)? = nil
    ) {
        guard node.isDirectory else {
            completion?()
            return
        }
        if node.children != nil {
            completion?()
            return
        }

        let url = node.url.standardizedFileURL
        guard !loadingNodes.contains(url) else {
            completion?()
            return
        }
        loadingNodes.insert(url)

        Task { [weak self, weak node] in
            do {
                let items = try await DirectoryScanner.items(in: url)
                guard let self, let node else { return }
                node.children = items.map {
                    NavigatorNode(
                        url: $0.url.standardizedFileURL,
                        isDirectory: $0.isDirectory
                    )
                }
                loadingNodes.remove(url)
                outlineView.reloadItem(node, reloadChildren: true)
                completion?()
            } catch {
                self?.loadingNodes.remove(url)
                completion?()
            }
        }
    }

    private func revealSelectedPDF() {
        guard let selectedPDFURL, let rootNode else {
            outlineView.deselectAll(nil)
            return
        }

        expandPath(to: selectedPDFURL, from: rootNode) { [weak self] node in
            guard let self else { return }
            guard let node else {
                outlineView.deselectAll(nil)
                return
            }
            let row = outlineView.row(forItem: node)
            guard row >= 0 else { return }
            outlineView.selectRowIndexes(
                IndexSet(integer: row),
                byExtendingSelection: false
            )
            outlineView.scrollRowToVisible(row)
        }
    }

    private func expandPath(
        to fileURL: URL,
        from node: NavigatorNode,
        completion: @escaping (NavigatorNode?) -> Void
    ) {
        guard fileURL.isDescendantOrSame(of: node.url) else {
            completion(nil)
            return
        }

        loadChildrenIfNeeded(for: node) { [weak self, weak node] in
            guard let self, let node else {
                completion(nil)
                return
            }

            if let child = node.children?.first(where: { $0.url == fileURL }) {
                completion(child)
                return
            }

            guard let directory = node.children?.first(where: {
                $0.isDirectory && fileURL.isDescendantOrSame(of: $0.url)
            }) else {
                completion(nil)
                return
            }

            outlineView.expandItem(directory)
            expandPath(to: fileURL, from: directory, completion: completion)
        }
    }

    @objc private func rowClicked() {
        let row = outlineView.clickedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? NavigatorNode,
              !node.isDirectory,
              NSApp.currentEvent?.modifierFlags.contains(.command) == true else {
            return
        }

        onOpenInNewTab(node.url.standardizedFileURL, .background)
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

    private var contextMenuPDFURL: URL? {
        let clickedRow = outlineView.clickedRow
        let row = clickedRow >= 0 ? clickedRow : outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? NavigatorNode,
              !node.isDirectory else {
            return nil
        }
        return node.url.standardizedFileURL
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = menu.addItem(
            withTitle: "Open",
            action: #selector(openClickedRow(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        let newTabItem = menu.addItem(
            withTitle: "Open in New Tab",
            action: #selector(openClickedRowInNewTab(_:)),
            keyEquivalent: ""
        )
        newTabItem.target = self
        menu.addItem(.separator())
        let defaultAppItem = menu.addItem(
            withTitle: "Open in Default App",
            action: #selector(openClickedRowInDefaultApp(_:)),
            keyEquivalent: ""
        )
        defaultAppItem.target = self
        let finderItem = menu.addItem(
            withTitle: "Show in Finder",
            action: #selector(showClickedRowInFinder(_:)),
            keyEquivalent: ""
        )
        finderItem.target = self
        return menu
    }
}

extension NavigatorController: NSOutlineViewDataSource {
    func outlineView(
        _ outlineView: NSOutlineView,
        numberOfChildrenOfItem item: Any?
    ) -> Int {
        if let node = item as? NavigatorNode {
            return node.children?.count ?? 0
        }
        return rootNode?.children?.count ?? 0
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        child index: Int,
        ofItem item: Any?
    ) -> Any {
        if let node = item as? NavigatorNode {
            return node.children![index]
        }
        return rootNode!.children![index]
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        isItemExpandable item: Any
    ) -> Bool {
        (item as? NavigatorNode)?.isDirectory == true
    }
}

extension NavigatorController: NSOutlineViewDelegate {
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? NavigatorNode else {
            return
        }
        loadChildrenIfNeeded(for: node)
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let node = item as? NavigatorNode else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("NavigatorCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(
            withIdentifier: identifier,
            owner: self
        ) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            textField.cell?.usesSingleLineMode = true
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(
                    equalTo: imageView.trailingAnchor,
                    constant: 6
                ),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = node.name
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: node.url.path)
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is NavigatorNode
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard NSApp.currentEvent?.modifierFlags.contains(.command) != true else {
            return
        }
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? NavigatorNode,
              !node.isDirectory else {
            return
        }

        let requestedURL = node.url.standardizedFileURL
        guard requestedURL != selectedPDFURL else { return }
        onSelectPDF(requestedURL)
    }
}

private final class NavigatorNode: NSObject {
    let url: URL
    let isDirectory: Bool
    var children: [NavigatorNode]?

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    var name: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}

private extension URL {
    func isDescendantOrSame(of other: URL) -> Bool {
        let mine = standardizedFileURL.path
        let root = other.standardizedFileURL.path
        return mine == root || mine.hasPrefix(root + "/")
    }
}
