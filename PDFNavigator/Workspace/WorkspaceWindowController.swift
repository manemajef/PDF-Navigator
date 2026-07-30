import AppKit

final class WorkspaceWindowController: NSWindowController, NSWindowDelegate {
    private let pdfReaderController = PDFReaderController()
    private let placeholderController = WorkspacePlaceholderController()
    private lazy var splitController = WorkspaceSplitViewController(
        pdfReaderController: pdfReaderController,
        placeholderController: placeholderController
    )

    private var workspaceRootURL: URL?
    private var selectedPDFURL: URL?
    private var navigationHistory = NavigationHistory()

    var onClose: (() -> Void)?
    var openWorkspaceInNewTab: ((WorkspaceOpenRequest) -> Void)?
    var onSelectedPDF: ((URL) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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
        updateWindowIdentity()
        showCurrentWorkspace()

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureWindow() {
        guard let window else { return }
        window.delegate = self
        nextResponder = window.nextResponder
        window.nextResponder = self
        window.tabbingIdentifier = "WorkspaceWindow"
        window.tabbingMode = .automatic
        window.toolbarStyle = .automatic
        window.setContentSize(NSSize(width: 1000, height: 760))
        window.center()

        let toolbar = NSToolbar(identifier: "WorkspaceToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window.toolbar = toolbar
        window.contentViewController = splitController

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
        navigationHistory.visit(url)
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

    func windowWillClose(_ notification: Notification) {
        onClose?()
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
        showHistoricalSelection(url)
    }

    @objc func goForward(_ sender: Any?) {
        guard let url = navigationHistory.goForward() else { return }
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
        updateWindowIdentity()
        splitController.selectPDF(url)
        onSelectedPDF?(url)
    }
}

extension WorkspaceWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .flexibleSpace,
            .workspaceBack,
            .workspaceForward,
            .workspaceSearch,
            .workspaceNewTab
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .flexibleSpace,
            .workspaceBack,
            .workspaceForward,
            .workspaceSearch,
            .workspaceNewTab
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleSidebar:
            return toolbarItem(
                identifier: itemIdentifier,
                label: "Sidebar",
                symbolName: "sidebar.left",
                action: #selector(toggleSidebar(_:))
            )
        case .workspaceBack:
            return toolbarItem(
                identifier: itemIdentifier,
                label: "Back",
                symbolName: "chevron.backward",
                action: #selector(goBack(_:))
            )
        case .workspaceForward:
            return toolbarItem(
                identifier: itemIdentifier,
                label: "Forward",
                symbolName: "chevron.forward",
                action: #selector(goForward(_:))
            )
        case .workspaceNewTab:
            return toolbarItem(
                identifier: itemIdentifier,
                label: "New Tab",
                symbolName: "plus.rectangle.on.rectangle",
                action: #selector(newWorkspaceTab(_:))
            )
        case .workspaceSearch:
            let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Search"
            item.paletteLabel = "Search"
            item.searchField.placeholderString = "Search"
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
    static let workspaceBack = NSToolbarItem.Identifier("WorkspaceBack")
    static let workspaceForward = NSToolbarItem.Identifier("WorkspaceForward")
    static let workspaceNewTab = NSToolbarItem.Identifier("WorkspaceNewTab")
    static let workspaceSearch = NSToolbarItem.Identifier("WorkspaceSearch")
}

final class WorkspacePlaceholderController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
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

        view = container
    }

    func display(workspaceRootURL: URL?) {
        loadViewIfNeeded()
        if let workspaceRootURL {
            titleLabel.stringValue = workspaceRootURL.lastPathComponent.isEmpty
                ? "Workspace"
                : workspaceRootURL.lastPathComponent
            subtitleLabel.stringValue = workspaceRootURL.path
        } else {
            titleLabel.stringValue = "PDF Navigator"
            subtitleLabel.stringValue = "Open a PDF or folder to begin."
        }
    }
}
