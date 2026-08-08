import AppKit

/// The native outline implementation owned by `SidebarController`.
final class NavigatorController: NSViewController {
    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private let rootSection = NavigatorSection()

    private var rootURL: URL
    private var selectedPDFURL: URL?
    private var onSelectPDF: (URL) -> Void
    private var onOpenInNewTab: (URL, TabActivation) -> Void
    private var onItemCountChange: (Int?) -> Void

    private var rootChildren: [NavigatorNode]?
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
        rootSection.title = Self.workspaceName(self.rootURL)
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
        outlineView.floatsGroupRows = false
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
        rootSection.title = Self.workspaceName(rootURL)

        loadViewIfNeeded()
        if rootChanged {
            reloadTree()
        } else {
            outlineView.reloadItem(rootSection)
            revealSelectedPDF()
        }
    }

    private func reloadTree() {
        loadingNodes.removeAll()
        rootChildren = nil
        outlineView.reloadData()
        outlineView.expandItem(rootSection)

        loadRootChildrenIfNeeded { [weak self] in
            guard let self else { return }
            outlineView.reloadItem(rootSection, reloadChildren: true)
            outlineView.expandItem(rootSection)
            onItemCountChange(rootChildren?.count)
            revealSelectedPDF()
        }
    }

    private func loadRootChildrenIfNeeded(completion: (() -> Void)? = nil) {
        if rootChildren != nil {
            completion?()
            return
        }

        let url = rootURL.standardizedFileURL
        guard !loadingNodes.contains(url) else {
            completion?()
            return
        }
        loadingNodes.insert(url)

        Task { [weak self] in
            do {
                let items = try await DirectoryScanner.items(in: url)
                guard let self else { return }
                rootChildren = items.map {
                    NavigatorNode(
                        url: $0.url.standardizedFileURL,
                        isDirectory: $0.isDirectory
                    )
                }
                loadingNodes.remove(url)
                outlineView.reloadItem(rootSection, reloadChildren: true)
                completion?()
            } catch {
                self?.loadingNodes.remove(url)
                completion?()
            }
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
        guard let selectedPDFURL else {
            outlineView.deselectAll(nil)
            return
        }
        guard selectedPDFURL.isDescendantOrSame(of: rootURL) else {
            outlineView.deselectAll(nil)
            return
        }

        outlineView.expandItem(rootSection)
        loadRootChildrenIfNeeded { [weak self] in
            guard let self else { return }
            expandPath(to: selectedPDFURL, through: rootChildren ?? []) { [weak self] node in
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
    }

    private func expandPath(
        to fileURL: URL,
        through nodes: [NavigatorNode],
        completion: @escaping (NavigatorNode?) -> Void
    ) {
        if let child = nodes.first(where: { $0.url == fileURL }) {
            completion(child)
            return
        }

        guard let directory = nodes.first(where: {
            $0.isDirectory && fileURL.isDescendantOrSame(of: $0.url)
        }) else {
            completion(nil)
            return
        }

        outlineView.expandItem(directory)
        loadChildrenIfNeeded(for: directory) { [weak self, weak directory] in
            guard let self, let directory else {
                completion(nil)
                return
            }
            expandPath(
                to: fileURL,
                through: directory.children ?? [],
                completion: completion
            )
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

    private func toggleRootSection() {
        if outlineView.isItemExpanded(rootSection) {
            outlineView.collapseItem(rootSection)
        } else {
            outlineView.expandItem(rootSection)
        }
        updateRootSectionDisclosure()
    }

    private func updateRootSectionDisclosure() {
        let row = outlineView.row(forItem: rootSection)
        guard row >= 0,
              let cell = outlineView.view(
                atColumn: 0,
                row: row,
                makeIfNecessary: false
              ) as? NavigatorSectionCellView else {
            return
        }
        cell.setExpanded(outlineView.isItemExpanded(rootSection))
    }

    private static func workspaceName(_ url: URL) -> String {
        url.lastPathComponent.isEmpty
            ? url.path
            : FileManager.default.displayName(atPath: url.path)
    }
}

extension NavigatorController: NSOutlineViewDataSource {
    func outlineView(
        _ outlineView: NSOutlineView,
        numberOfChildrenOfItem item: Any?
    ) -> Int {
        if item == nil {
            return 1
        }
        if item as? NavigatorSection === rootSection {
            return rootChildren?.count ?? 0
        }
        if let node = item as? NavigatorNode {
            return node.children?.count ?? 0
        }
        return 0
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        child index: Int,
        ofItem item: Any?
    ) -> Any {
        if item == nil {
            return rootSection
        }
        if item as? NavigatorSection === rootSection {
            return rootChildren![index]
        }
        if let node = item as? NavigatorNode {
            return node.children![index]
        }
        assertionFailure("Unexpected navigator item")
        return rootSection
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        isItemExpandable item: Any
    ) -> Bool {
        if item as? NavigatorSection === rootSection {
            return true
        }
        return (item as? NavigatorNode)?.isDirectory == true
    }
}

extension NavigatorController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is NavigatorSection
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        shouldShowOutlineCellForItem item: Any
    ) -> Bool {
        !(item is NavigatorSection)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        if notification.userInfo?["NSObject"] is NavigatorSection {
            updateRootSectionDisclosure()
            return
        }
        guard let node = notification.userInfo?["NSObject"] as? NavigatorNode else {
            return
        }
        loadChildrenIfNeeded(for: node)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        if notification.userInfo?["NSObject"] is NavigatorSection {
            updateRootSectionDisclosure()
        }
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        if let section = item as? NavigatorSection {
            return makeSectionView(for: section, in: outlineView)
        }

        guard let node = item as? NavigatorNode else { return nil }
        return makeNodeView(for: node, in: outlineView)
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

    private func makeSectionView(
        for section: NavigatorSection,
        in outlineView: NSOutlineView
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("NavigatorSectionCell")
        let cell: NavigatorSectionCellView
        if let reused = outlineView.makeView(
            withIdentifier: identifier,
            owner: self
        ) as? NavigatorSectionCellView {
            cell = reused
        } else {
            cell = NavigatorSectionCellView()
            cell.identifier = identifier
        }

        cell.configure(
            title: section.title,
            isExpanded: outlineView.isItemExpanded(section),
            onToggle: { [weak self] in self?.toggleRootSection() }
        )
        return cell
    }

    private func makeNodeView(
        for node: NavigatorNode,
        in outlineView: NSOutlineView
    ) -> NSView? {
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
}

private final class NavigatorSection: NSObject {
    var title = "Workspace"
}

private final class NavigatorSectionCellView: NSTableCellView {
    private let titleField = NSTextField(labelWithString: "")
    private let disclosureButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var onToggle: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUpView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        disclosureButton.animator().alphaValue = 1
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        disclosureButton.animator().alphaValue = 0
    }

    func configure(
        title: String,
        isExpanded: Bool,
        onToggle: @escaping () -> Void
    ) {
        titleField.stringValue = title
        self.onToggle = onToggle
        setExpanded(isExpanded)
    }

    func setExpanded(_ isExpanded: Bool) {
        disclosureButton.image = NSImage(
            systemSymbolName: isExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: isExpanded ? "Collapse" : "Expand"
        )
    }

    private func setUpView() {
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 12, weight: .semibold)
        titleField.textColor = .secondaryLabelColor
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.cell?.usesSingleLineMode = true
        addSubview(titleField)
        textField = titleField

        disclosureButton.translatesAutoresizingMaskIntoConstraints = false
        disclosureButton.bezelStyle = .shadowlessSquare
        disclosureButton.isBordered = false
        disclosureButton.imagePosition = .imageOnly
        disclosureButton.contentTintColor = .secondaryLabelColor
        disclosureButton.alphaValue = 0
        disclosureButton.target = self
        disclosureButton.action = #selector(toggleDisclosure)
        addSubview(disclosureButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            titleField.trailingAnchor.constraint(
                lessThanOrEqualTo: disclosureButton.leadingAnchor,
                constant: -6
            ),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosureButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            disclosureButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosureButton.widthAnchor.constraint(equalToConstant: 18),
            disclosureButton.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    @objc private func toggleDisclosure() {
        onToggle?()
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
