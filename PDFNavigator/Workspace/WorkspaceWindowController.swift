import AppKit

final class WorkspaceWindowController: NSWindowController {
    private let pdfReaderController = PDFReaderController()
    private let placeholderController = WorkspacePlaceholderController()
    private lazy var splitController = WorkspaceSplitViewController(
        pdfReaderController: pdfReaderController,
        placeholderController: placeholderController
    )

    private var workspaceRootURL: URL?
    private var selectedPDFURL: URL?
    private var navigationHistory = NavigationHistory()
    private weak var navigationToolbarItem: NSToolbarItemGroup?

    var openWorkspaceInNewTab: ((WorkspaceOpenRequest) -> Void)?
    var onSelectedPDF: ((URL) -> Void)?
    var chooseWorkspace: (() -> Void)? {
        didSet { placeholderController.onChooseWorkspace = chooseWorkspace }
    }
    var openRecentPDF: ((URL) -> Void)? {
        didSet { placeholderController.onOpenRecentPDF = openRecentPDF }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 850),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PDF Navigator"
        window.animationBehavior = .default
        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func display(workspaceRootURL: URL?, selectedPDFURL: URL?) {
        self.workspaceRootURL = workspaceRootURL?.standardizedFileURL
        self.selectedPDFURL = selectedPDFURL?.standardizedFileURL
        navigationHistory.reset(to: self.selectedPDFURL)
        updateNavigationToolbar()
        updateWindowIdentity()
        showCurrentWorkspace()
    }

    private func configureWindow() {
        guard let window else { return }
        window.tabbingIdentifier = "WorkspaceWindow"
        window.tabbingMode = .automatic
        window.toolbarStyle = .unified
        window.autorecalculatesKeyViewLoop = true

        let toolbar = NSToolbar(identifier: "WorkspaceToolbarV3")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window.toolbar = toolbar
        window.contentViewController = splitController

        let visibleWidth = NSScreen.main?.visibleFrame.width ?? 1_050
        let documentWidth = min(
            max(700, floor(visibleWidth * 2 / 3)),
            max(700, visibleWidth - 80)
        )
        window.setContentSize(NSSize(width: documentWidth, height: 850))
        window.center()

        splitController.onSelectPDF = { [weak self] url in
            self?.selectPDF(url)
        }
        splitController.onOpenPDFInNewTab = { [weak self] url in
            self?.openWorkspaceInNewTab?(.pdf(url))
        }
    }

    private func selectPDF(_ url: URL) {
        let url = url.standardizedFileURL
        guard selectedPDFURL != url else { return }
        selectedPDFURL = url
        (document as? WorkspaceDocument)?.selectPDF(url)
        navigationHistory.visit(url)
        updateNavigationToolbar()
        updateWindowIdentity()
        splitController.selectPDF(url)
        onSelectedPDF?(url)
    }

    private func showCurrentWorkspace() {
        splitController.display(
            workspaceRootURL: workspaceRootURL,
            selectedPDFURL: selectedPDFURL
        )
    }

    private func updateWindowIdentity() {
        guard let window else { return }

        if let selectedPDFURL {
            window.title = selectedPDFURL.lastPathComponent
            window.representedURL = selectedPDFURL
        } else if let workspaceRootURL {
            window.title = workspaceRootURL.lastPathComponent.isEmpty
                ? workspaceRootURL.path
                : workspaceRootURL.lastPathComponent
            window.representedURL = workspaceRootURL
        } else {
            window.title = "PDF Navigator"
            window.representedURL = nil
        }
    }

    @objc func newWorkspaceTab(_ sender: Any?) {
        if let workspaceRootURL {
            openWorkspaceInNewTab?(.folder(workspaceRootURL))
        } else {
            openWorkspaceInNewTab?(.empty)
        }
    }

    @objc func goBack(_ sender: Any?) {
        guard let url = navigationHistory.goBack() else { return }
        updateNavigationToolbar()
        showHistoricalSelection(url)
    }

    @objc func goForward(_ sender: Any?) {
        guard let url = navigationHistory.goForward() else { return }
        updateNavigationToolbar()
        showHistoricalSelection(url)
    }

    @objc func toggleSidebar(_ sender: Any?) {
        splitController.toggleSidebar(sender)
    }

    @objc func beginSearch(_ sender: Any?) {
        guard let searchItem = window?.toolbar?.items.first(where: {
            $0.itemIdentifier == .workspaceSearch
        }) as? NSSearchToolbarItem else {
            return
        }
        searchItem.beginSearchInteraction()
    }

    @objc func searchFieldChanged(_ sender: NSSearchField) {
        pdfReaderController.search(sender.stringValue)
    }

    @objc func selectNextSearchMatch(_ sender: Any?) {
        pdfReaderController.selectNextSearchMatch()
    }

    @objc func selectPreviousSearchMatch(_ sender: Any?) {
        pdfReaderController.selectPreviousSearchMatch()
    }

    @objc func goToPreviousPage(_ sender: Any?) {
        pdfReaderController.goToPreviousPage()
    }

    @objc func goToNextPage(_ sender: Any?) {
        pdfReaderController.goToNextPage()
    }

    @objc func zoomIn(_ sender: Any?) {
        pdfReaderController.zoomIn()
    }

    @objc func zoomOut(_ sender: Any?) {
        pdfReaderController.zoomOut()
    }

    @objc func showActualSize(_ sender: Any?) {
        pdfReaderController.showActualSize()
    }

    @objc func zoomToFit(_ sender: Any?) {
        pdfReaderController.zoomToFit()
    }

    @objc func openCurrentPDFInDefaultApp(_ sender: Any?) {
        pdfReaderController.openInDefaultApp()
    }

    @objc func shareCurrentPDF(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        pdfReaderController.share(from: contentView)
    }

    private func showHistoricalSelection(_ url: URL) {
        selectedPDFURL = url.standardizedFileURL
        (document as? WorkspaceDocument)?.selectPDF(url)
        updateWindowIdentity()
        splitController.selectPDF(url)
        onSelectedPDF?(url)
    }

    private func updateNavigationToolbar() {
        guard let subitems = navigationToolbarItem?.subitems,
              subitems.count == 2 else {
            return
        }
        subitems[0].isEnabled = navigationHistory.canGoBack
        subitems[1].isEnabled = navigationHistory.canGoForward
    }
}

extension WorkspaceWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceNavigation,
            .flexibleSpace,
            .workspaceNewTab,
            .workspaceSearch
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceNavigation,
            .flexibleSpace,
            .workspaceNewTab,
            .workspaceSearch
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .workspaceNavigation:
            let labels = ["Back", "Forward"]
            let images = [
                NSImage(
                    systemSymbolName: "chevron.backward",
                    accessibilityDescription: labels[0]
                ),
                NSImage(
                    systemSymbolName: "chevron.forward",
                    accessibilityDescription: labels[1]
                )
            ].compactMap { $0 }
            guard images.count == labels.count else { return nil }

            let item = NSToolbarItemGroup(
                itemIdentifier: itemIdentifier,
                images: images,
                selectionMode: .momentary,
                labels: labels,
                target: nil,
                action: nil
            )
            item.label = "Navigation"
            item.paletteLabel = "Navigation"
            item.isNavigational = true
            item.controlRepresentation = .expanded
            item.subitems[0].target = self
            item.subitems[0].action = #selector(goBack(_:))
            item.subitems[0].toolTip = labels[0]
            item.subitems[1].target = self
            item.subitems[1].action = #selector(goForward(_:))
            item.subitems[1].toolTip = labels[1]
            navigationToolbarItem = item
            updateNavigationToolbar()
            return item
        case .workspaceNewTab:
            return toolbarItem(
                identifier: itemIdentifier,
                label: "New Tab",
                symbolName: "plus",
                action: #selector(newWorkspaceTab(_:))
            )
        case .workspaceSearch:
            let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Search"
            item.paletteLabel = "Search"
            item.searchField.placeholderString = "Search Current PDF"
            item.searchField.target = self
            item.searchField.action = #selector(searchFieldChanged(_:))
            item.searchField.isContinuous = true
            return item
        default:
            return nil
        }
    }

    private func toolbarItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.target = self
        item.action = action
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        return item
    }
}

extension WorkspaceWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(goBack(_:)):
            return navigationHistory.canGoBack
        case #selector(goForward(_:)):
            return navigationHistory.canGoForward
        case #selector(toggleSidebar(_:)),
             #selector(newWorkspaceTab(_:)):
            return true
        case #selector(beginSearch(_:)),
             #selector(selectNextSearchMatch(_:)),
             #selector(selectPreviousSearchMatch(_:)),
             #selector(goToPreviousPage(_:)),
             #selector(goToNextPage(_:)),
             #selector(zoomIn(_:)),
             #selector(zoomOut(_:)),
             #selector(showActualSize(_:)),
             #selector(zoomToFit(_:)),
             #selector(openCurrentPDFInDefaultApp(_:)),
             #selector(shareCurrentPDF(_:)):
            return pdfReaderController.hasDocument
        default:
            return true
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let workspaceNavigation = NSToolbarItem.Identifier("WorkspaceNavigation")
    static let workspaceNewTab = NSToolbarItem.Identifier("WorkspaceNewTab")
    static let workspaceSearch = NSToolbarItem.Identifier("WorkspaceSearch")
}

final class WorkspacePlaceholderController: NSViewController {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let openButton = NSButton()
    private let recentPDFsStack = NSStackView()
    private var recentPDFs: [URL] = []

    var onChooseWorkspace: (() -> Void)?
    var onOpenRecentPDF: ((URL) -> Void)?

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 54, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor

        openButton.target = self
        openButton.action = #selector(chooseWorkspace)
        openButton.controlSize = .large
        openButton.bezelStyle = .rounded

        recentPDFsStack.orientation = .vertical
        recentPDFsStack.alignment = .leading
        recentPDFsStack.spacing = 0

        let recentPDFsBox = NSBox()
        recentPDFsBox.title = "Recent PDFs"
        recentPDFsBox.contentView = recentPDFsStack
        recentPDFsBox.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(
            views: [iconView, titleLabel, subtitleLabel, openButton, recentPDFsBox]
        )
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(20, after: subtitleLabel)
        stack.setCustomSpacing(20, after: openButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.maximumNumberOfLines = 2

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32)
        ])
        let preferredWidth = recentPDFsBox.widthAnchor.constraint(equalToConstant: 440)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true

        view = container
    }

    func display(workspaceRootURL: URL?) {
        loadViewIfNeeded()
        if let workspaceRootURL {
            iconView.image = NSImage(
                systemSymbolName: "folder",
                accessibilityDescription: "Workspace"
            )
            titleLabel.stringValue = workspaceRootURL.lastPathComponent.isEmpty
                ? "Workspace"
                : workspaceRootURL.lastPathComponent
            subtitleLabel.stringValue = workspaceRootURL.path
            openButton.title = "Open Different Workspace"
        } else {
            iconView.image = NSImage(
                systemSymbolName: "doc.richtext",
                accessibilityDescription: "PDF Navigator"
            )
            titleLabel.stringValue = "PDF Navigator"
            subtitleLabel.stringValue = "Open a PDF or folder to begin."
            openButton.title = "Open New"
        }
        reloadRecentPDFs(in: workspaceRootURL)
    }

    @objc private func chooseWorkspace() {
        onChooseWorkspace?()
    }

    @objc private func openRecentPDF(_ sender: NSButton) {
        guard recentPDFs.indices.contains(sender.tag) else { return }
        onOpenRecentPDF?(recentPDFs[sender.tag])
    }

    private func reloadRecentPDFs(in workspaceRootURL: URL?) {
        recentPDFs = Array(
            RecentLocationsStore.shared.recentPDFs
                .filter { url in
                    guard let workspaceRootURL else { return true }
                    let rootPath = workspaceRootURL.standardizedFileURL.path
                    let urlPath = url.standardizedFileURL.path
                    return urlPath.hasPrefix(rootPath + "/")
                }
                .prefix(5)
        )

        for view in recentPDFsStack.arrangedSubviews {
            recentPDFsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if recentPDFs.isEmpty {
            let label = NSTextField(labelWithString: "No recent PDFs.")
            label.textColor = .secondaryLabelColor
            recentPDFsStack.addArrangedSubview(label)
            return
        }

        for (index, url) in recentPDFs.enumerated() {
            let button = NSButton(
                title: url.lastPathComponent,
                target: self,
                action: #selector(openRecentPDF(_:))
            )
            button.tag = index
            button.bezelStyle = .inline
            button.alignment = .left
            button.image = NSImage(
                systemSymbolName: "doc",
                accessibilityDescription: nil
            )
            button.imagePosition = .imageLeading
            recentPDFsStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: recentPDFsStack.widthAnchor).isActive = true
        }
    }
}
