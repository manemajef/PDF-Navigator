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
            self?.updateWindowSubtitle()
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
        synchronizeWindowTitleWithDocumentName()
        updateWindowSubtitle()
    }

    var isZoomToFitActive: Bool {
        readerController.isZoomToFitActive
    }

    var isActualSizeActive: Bool {
        readerController.isActualSizeActive
    }

    private func configureWindow() {
        guard let window else { return }
        // Before the content view controller is installed: loading it renders
        // the document, which publishes a subtitle. Without this the window
        // spends the whole first render showing a page count under the
        // placeholder title.
        synchronizeWindowTitleWithDocumentName()
        // Every restorable window needs its own identifier: AppKit keys saved
        // window state by it, so a shared value collapses all tabs into one
        // entry. The restoration class is left to `NSWindowController`, which
        // points document windows at `NSDocumentController`.
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier(UUID().uuidString)
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
        // The title depends only on the session, so it is set before rendering:
        // `renderMode` loads the document, and waiting for that would leave the
        // previous file's name in the titlebar for as long as the load takes.
        // The subtitle can only follow, since the page count comes from the
        // document `renderMode` installs.
        case .root:
            synchronizeWindowTitleWithDocumentName()
            contentController.renderMode()
            updateWindowSubtitle()
            RecentLocationsStore.shared.noteWorkspace(session.root)
            invalidateDocumentRestorableState()

        case .selection:
            synchronizeWindowTitleWithDocumentName()
            contentController.renderMode()
            updateWindowSubtitle()
            toolbar.updatePDFAvailability(
                session.pdfSession?.hasDocument == true
            )
            updateZoomControls()
            if let selection = session.selection {
                RecentLocationsStore.shared.notePDF(selection)
            }
            invalidateDocumentRestorableState()

        case .history:
            toolbar.updateNavigation(
                canGoBack: session.canGoBack,
                canGoForward: session.canGoForward
            )
        }
    }

    /// The document encodes the session's location, so it is the object whose
    /// restorable state goes stale when the session navigates.
    private func invalidateDocumentRestorableState() {
        (document as? NSDocument)?.invalidateRestorableState()
    }

    /// AppKit's own hook for pushing document identity into the titlebar. It
    /// fires whenever `NSDocument.fileURL` changes, and the inherited
    /// implementation would point the title and proxy icon at the document —
    /// which here is the *workspace folder*, not the open PDF. Overriding it
    /// makes the session the single authority, so an AppKit-initiated sync can
    /// no longer race the session and stomp the filename with the folder name.
    override func synchronizeWindowTitleWithDocumentName() {
        guard let window else { return }

        let title = session.windowTitle
        if window.title != title {
            window.title = title
        }
        if window.representedURL != session.representedURL {
            window.representedURL = session.representedURL
        }
        updateTitlebarAppearance()
    }

    /// Deliberately separate from the title: this changes on every scroll, and
    /// reassigning `representedURL` at that rate makes AppKit re-resolve the
    /// proxy icon for the file each time.
    private func updateWindowSubtitle() {
        guard let window else { return }

        let subtitle = session.pdfSession?.hasDocument == true
            ? (readerController.presentationState.pageSummary ?? "")
            : ""
        if window.subtitle != subtitle {
            window.subtitle = subtitle
        }
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
