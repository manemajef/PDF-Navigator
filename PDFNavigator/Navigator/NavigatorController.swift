import AppKit

@MainActor
final class NavigatorController: NSViewController {
    var onSelectPDF: ((URL) -> Void)?
    var onOpenPDFInNewTab: ((URL) -> Void)?

    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private var rootNode: NavigatorNode?
    private var selectedPDFURL: URL?
    private var loadingNodes: Set<URL> = []

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        container.addSubview(scrollView)

        outlineView.style = .sourceList
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(rowClicked)
        outlineView.indentationPerLevel = 14
        outlineView.refusesFirstResponder = true
        outlineView.menu = makeContextMenu()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        scrollView.documentView = outlineView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        view = container
    }

    func display(workspaceRootURL: URL?, selectedPDFURL: URL?) {
        loadViewIfNeeded()
        let standardizedRoot = workspaceRootURL?.standardizedFileURL
        self.selectedPDFURL = selectedPDFURL?.standardizedFileURL

        if rootNode?.url != standardizedRoot {
            loadingNodes.removeAll()
            rootNode = standardizedRoot.map {
                NavigatorNode(url: $0, isDirectory: true)
            }
            outlineView.reloadData()
            if let rootNode {
                outlineView.expandItem(rootNode)
                loadChildrenIfNeeded(for: rootNode) { [weak self] in
                    self?.revealSelectedPDF()
                }
            }
        } else {
            revealSelectedPDF()
        }
    }

    func setSelectedPDF(_ url: URL) {
        selectedPDFURL = url.standardizedFileURL
        revealSelectedPDF()
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
                    NavigatorNode(url: $0.url.standardizedFileURL, isDirectory: $0.isDirectory)
                }
                loadingNodes.remove(url)
                outlineView.reloadItem(node, reloadChildren: true)
                completion?()
            } catch is CancellationError {
                self?.loadingNodes.remove(url)
                completion?()
            } catch {
                self?.loadingNodes.remove(url)
                completion?()
            }
        }
    }

    private func revealSelectedPDF() {
        guard let selectedPDFURL,
              let rootNode else {
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
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
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
              !node.isDirectory else {
            return
        }

        let requestedURL = node.url.standardizedFileURL
        guard requestedURL != selectedPDFURL else { return }
        if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
            onOpenPDFInNewTab?(requestedURL)
            return
        }
        onSelectPDF?(requestedURL)
    }

    @objc private func openClickedRowInNewTab(_ sender: Any?) {
        let clickedRow = outlineView.clickedRow
        let row = clickedRow >= 0 ? clickedRow : outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? NavigatorNode,
              !node.isDirectory else {
            return
        }
        onOpenPDFInNewTab?(node.url.standardizedFileURL)
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let item = menu.addItem(
            withTitle: "Open in New Tab",
            action: #selector(openClickedRowInNewTab(_:)),
            keyEquivalent: ""
        )
        item.target = self
        return menu
    }
}

extension NavigatorController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? NavigatorNode {
            return node.children?.count ?? 0
        }
        return rootNode == nil ? 0 : 1
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? NavigatorNode {
            return node.children![index]
        }
        return rootNode!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? NavigatorNode else { return false }
        return node.isDirectory
    }
}

extension NavigatorController: NSOutlineViewDelegate {
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? NavigatorNode else { return }
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
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
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

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = node.name
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: node.url.path)
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let node = item as? NavigatorNode else { return false }
        return !node.isDirectory
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
