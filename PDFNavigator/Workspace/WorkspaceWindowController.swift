import AppKit

final class WorkspaceWindowController: NSWindowController {
    private let pdfReaderController = PDFReaderController()
    private let welcomeController = WelcomeController()
    private let workspaceHomeController = WorkspaceHomeController()
    private lazy var workspaceToolbar = WorkspaceToolbar(target: self)
    private lazy var splitController = WorkspaceSplitViewController(
        pdfReaderController: pdfReaderController,
        welcomeController: welcomeController,
        workspaceHomeController: workspaceHomeController
    )

    private var workspaceRootURL: URL?
    private var selectedPDFURL: URL?
    private var navigationHistory = NavigationHistory()

    var openWorkspaceInNewTab: ((WorkspaceOpenRequest) -> Void)?
    var onSelectedPDF: ((URL) -> Void)?
    var chooseWorkspace: (() -> Void)? {
        didSet {
            welcomeController.onChooseWorkspace = chooseWorkspace
            workspaceHomeController.onChooseWorkspace = chooseWorkspace
        }
    }
    var openRecentPDF: ((URL) -> Void)? {
        didSet {
            welcomeController.onOpenRecentPDF = openRecentPDF
            workspaceHomeController.onOpenRecentPDF = openRecentPDF
        }
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

        window.toolbar = workspaceToolbar.makeToolbar()
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
        workspaceToolbar.beginSearch()
    }

    @objc func searchFieldChanged(_ sender: NSSearchField) {
        pdfReaderController.search(sender.stringValue)
    }

    @objc func searchFieldSubmitted(_ sender: NSSearchField) {
        pdfReaderController.selectNextSearchMatch()
    }

    func endSearchInteraction() {
        workspaceToolbar.endSearch()
        window?.makeFirstResponder(nil)
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
        workspaceToolbar.updateNavigation(
            canGoBack: navigationHistory.canGoBack,
            canGoForward: navigationHistory.canGoForward
        )
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
