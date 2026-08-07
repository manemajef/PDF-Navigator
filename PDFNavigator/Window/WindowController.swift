import AppKit
import Combine

final class WindowController: NSWindowController {
    let session: TabSession
    let routing = WindowRouting()

    private let readerController = PDFReaderController()
    private var sessionChangesSubscription: AnyCancellable?
    private lazy var toolbar = WindowToolbar(target: self)

    private lazy var workspaceActions = WorkspaceActions(
        chooseLocation: { [weak routing] in routing?.chooseLocation() },
        openInNewTab: { [weak routing] in routing?.openInNewTab($0, $1) },
        revealInFinder: {
            NSWorkspace.shared.activateFileViewerSelecting([$0])
        },
        beginSearch: {
            NSApp.sendAction(
                #selector(WindowController.beginSearch(_:)),
                to: nil,
                from: nil
            )
        }
    )

    private lazy var contentController = WorkspaceSplitController(
        session: session,
        actions: workspaceActions,
        readerController: readerController,
        onInspectorPresentationChange: { [weak self] isVisible, section in
            self?.toolbar.updateInspectorPresentation(
                isVisible: isVisible,
                section: section
            )
        }
    )

    init(request: OpenRequest) {
        session = TabSession(request: request)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 850),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PDF Navigator"
        window.animationBehavior = .default
        super.init(window: window)

        readerController.onZoomStateChange = { [weak self] in
            self?.updateZoomControls()
        }
        readerController.onPageChange = { [weak self] in
            self?.updateWindowIdentity()
        }
        configureWindow()
        sessionChangesSubscription = session.changes.sink { [weak self] change in
            self?.apply(change)
        }
        apply(.root)
        apply(.selection)
        apply(.history)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func open(_ request: OpenRequest) {
        session.open(request)
    }

    func refreshWindowIdentity() {
        updateWindowIdentity()
    }

    var isZoomToFitActive: Bool {
        readerController.isZoomToFitActive
    }

    var isActualSizeActive: Bool {
        readerController.isActualSizeActive
    }

    private func configureWindow() {
        guard let window else { return }
        window.tabbingIdentifier = "WorkspaceWindow"
        window.tabbingMode = .automatic
        window.toolbarStyle = .unified
        window.autorecalculatesKeyViewLoop = true
        window.toolbar = toolbar.makeToolbar()
        window.contentViewController = contentController
        window.titlebarSeparatorStyle = .shadow
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTitlebarAppearance(_:)),
            name: NSWindow.didUpdateNotification,
            object: window
        )
        updateTitlebarAppearance()

        let visibleWidth = NSScreen.main?.visibleFrame.width ?? 1_050
        let documentWidth = min(
            max(700, floor(visibleWidth * 2 / 3)),
            max(700, visibleWidth - 80)
        )
        window.setContentSize(NSSize(width: documentWidth, height: 850))
        window.center()
    }

    private func apply(_ change: TabSession.Change) {
        switch change {
        case .root:
            contentController.renderMode()
            updateWindowIdentity()
            RecentLocationsStore.shared.noteWorkspace(session.root)

        case .selection:
            contentController.renderMode()
            updateWindowIdentity()
            toolbar.updatePDFAvailability(
                session.pdfSession?.hasDocument == true
            )
            updateZoomControls()
            if let selection = session.selection {
                RecentLocationsStore.shared.notePDF(selection)
            }

        case .history:
            toolbar.updateNavigation(
                canGoBack: session.canGoBack,
                canGoForward: session.canGoForward
            )
        }
    }

    private func updateWindowIdentity() {
        window?.title = session.windowTitle
        window?.representedURL = session.representedURL
        window?.subtitle = session.pdfSession?.hasDocument == true
            ? (readerController.pageSubtitle ?? "")
            : ""
        updateTitlebarAppearance()
    }

    @objc private func updateTitlebarAppearance(
        _ notification: Notification? = nil
    ) {
        guard let window else { return }

        let hasTabBar = window.tabGroup?.isTabBarVisible == true
        let hasToolbar = window.toolbar?.isVisible == true
        let isTitlebarOnly = !hasTabBar && !hasToolbar
        let hasPDF = session.pdfSession?.hasDocument == true

        let shouldBeTransparent = !hasPDF && isTitlebarOnly
        if window.titlebarAppearsTransparent != shouldBeTransparent {
            window.titlebarAppearsTransparent = shouldBeTransparent
        }

        let titleVisibility: NSWindow.TitleVisibility =
            (!hasPDF && isTitlebarOnly) ? .hidden : .visible
        if window.titleVisibility != titleVisibility {
            window.titleVisibility = titleVisibility
        }
    }

    // MARK: - Commands

    @objc func newTab(_ sender: Any?) {
        routing.newTab(.foreground)
    }

    @objc func openNewWorkspace(_ sender: Any?) {
        routing.chooseLocation()
    }

    @objc func goBack(_ sender: Any?) {
        session.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        session.goForward()
    }

    @objc func goToWorkspaceHome(_ sender: Any?) {
        session.goToWorkspaceHome()
    }

    @objc func toggleSidebar(_ sender: Any?) {
        contentController.toggleWorkspaceSidebar(sender)
    }

    @objc func toggleInspector(_ sender: Any?) {
        contentController.toggleInspectorSidebar(sender)
    }

    @objc func toggleThumbnailsPanel(_ sender: Any?) {
        contentController.toggleInspectorSection(.thumbnails)
    }

    @objc func toggleOutlinePanel(_ sender: Any?) {
        contentController.toggleInspectorSection(.outline)
    }

    @objc func toggleInfoPanel(_ sender: Any?) {
        contentController.toggleInspectorSection(.info)
    }

    @objc func customizeToolbar(_ sender: Any?) {
        window?.toolbar?.runCustomizationPalette(sender)
    }

    @objc func beginSearch(_ sender: Any?) {
        toolbar.beginSearch()
    }

    @objc func searchFieldChanged(_ sender: NSSearchField) {
        session.pdfSession?.search(sender.stringValue)
    }

    @objc func searchFieldSubmitted(_ sender: NSSearchField) {
        session.pdfSession?.selectNextMatch()
    }

    func endSearchInteraction() {
        toolbar.endSearch()
        window?.makeFirstResponder(nil)
    }

    @objc func selectNextSearchMatch(_ sender: Any?) {
        session.pdfSession?.selectNextMatch()
    }

    @objc func selectPreviousSearchMatch(_ sender: Any?) {
        session.pdfSession?.selectPreviousMatch()
    }

    @objc func goToPreviousPage(_ sender: Any?) {
        readerController.goToPreviousPage()
    }

    @objc func goToNextPage(_ sender: Any?) {
        readerController.goToNextPage()
    }

    @objc func zoomIn(_ sender: Any?) {
        readerController.zoomIn()
        updateZoomControls()
    }

    @objc func zoomOut(_ sender: Any?) {
        readerController.zoomOut()
        updateZoomControls()
    }

    @objc func showActualSize(_ sender: Any?) {
        readerController.showActualSize()
        updateZoomControls()
    }

    @objc func zoomToFit(_ sender: Any?) {
        readerController.zoomToFit()
        updateZoomControls()
    }

    @objc func openCurrentPDFInDefaultApp(_ sender: Any?) {
        readerController.openInDefaultApp()
    }

    @objc func shareCurrentPDF(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        readerController.share(from: contentView)
    }

    private func updateZoomControls() {
        toolbar.updateZoomControls(
            isZoomToFitActive: readerController.isZoomToFitActive,
            isActualSizeActive: readerController.isActualSizeActive
        )
    }
}

extension WindowController: NSMenuItemValidation, NSToolbarItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        canPerform(menuItem.action)
    }

    func validateToolbarItem(_ toolbarItem: NSToolbarItem) -> Bool {
        canPerform(toolbarItem.action)
    }

    private func canPerform(_ action: Selector?) -> Bool {
        switch action {
        case #selector(goBack(_:)):
            session.canGoBack
        case #selector(goForward(_:)):
            session.canGoForward
        case #selector(goToWorkspaceHome(_:)):
            session.canGoToWorkspaceHome
        case #selector(toggleSidebar(_:)),
             #selector(newTab(_:)),
             #selector(openNewWorkspace(_:)),
             #selector(customizeToolbar(_:)):
            true
        case #selector(toggleInspector(_:)):
            session.pdfSession?.hasDocument == true
        case #selector(toggleThumbnailsPanel(_:)),
             #selector(toggleOutlinePanel(_:)),
             #selector(toggleInfoPanel(_:)):
            session.pdfSession?.hasDocument == true
        case #selector(showActualSize(_:)):
            session.pdfSession?.hasDocument == true && !readerController.isActualSizeActive
        case #selector(zoomToFit(_:)):
            session.pdfSession?.hasDocument == true && !readerController.isZoomToFitActive
        case #selector(beginSearch(_:)),
             #selector(selectNextSearchMatch(_:)),
             #selector(selectPreviousSearchMatch(_:)),
             #selector(goToPreviousPage(_:)),
             #selector(goToNextPage(_:)),
             #selector(zoomIn(_:)),
             #selector(zoomOut(_:)),
             #selector(openCurrentPDFInDefaultApp(_:)),
             #selector(shareCurrentPDF(_:)):
            session.pdfSession?.hasDocument == true
        default:
            true
        }
    }
}
