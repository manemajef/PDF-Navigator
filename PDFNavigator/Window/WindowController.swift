import AppKit
import Combine

final class WindowController: NSWindowController {
    let session: WorkspaceSession
    let routing = WindowRouting()

    private let readerController = PDFReaderController()
    private var sessionChangesSubscription: AnyCancellable?
    private lazy var toolbar = ToolbarController(target: self)

    private lazy var windowActions = WindowActions(
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

    private lazy var contentController = WindowSplitController(
        session: session,
        actions: windowActions,
        readerController: readerController,
        onInspectorChange: { [weak self] in
            self?.renderToolbar()
        }
    )

    init(request: OpenRequest) {
        session = WorkspaceSession(request: request)
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
            self?.renderToolbar()
        }
        readerController.onPageChange = { [weak self] in
            self?.updateWindowSubtitle()
        }
        configureWindow()
        sessionChangesSubscription = session.changes.sink { [weak self] change in
            self?.render(change)
        }
        render(.workspace)
        render(.mode)
        render(.history)
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
        /// Runs before the content view controller is installed: loading it renders the document and publishes a subtitle
        synchronizeWindowTitleWithDocumentName()
        /// Every restorable window needs its own identifier
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier(UUID().uuidString)
        window.tabbingIdentifier = "WorkspaceWindow"
        window.tabbingMode = .automatic
        window.toolbarStyle = .unified
        window.autorecalculatesKeyViewLoop = true
        // No toolbar yet: which one belongs here is a function of the session's
        // mode, so the first `renderToolbar()` installs it. The window is not on
        // screen until after that runs.
        window.contentViewController = contentController
        window.titlebarSeparatorStyle = .shadow
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTitlebarTransparencyAndBlur(_:)),
            name: NSWindow.didUpdateNotification,
            object: window
        )
        updateTitlebarTransparencyAndBlur()

        let visibleWidth = NSScreen.main?.visibleFrame.width ?? 1_050
        let documentWidth = min(
            max(700, floor(visibleWidth * 2 / 3)),
            max(700, visibleWidth - 80)
        )
        window.setContentSize(NSSize(width: documentWidth, height: 850))
        window.center()
    }

    private func render(_ change: WorkspaceSession.Change) {
        switch change {
        // Everything a *new workspace* implies. The session always follows this
        // with `.mode`, so the title, content, and restorable state are that
        // case's job and are deliberately not repeated here.
        case .workspace:
            RecentLocationsStore.shared.noteWorkspace(session.root)

        // Order matters. The title comes from the session alone, so it is set
        // first — `contentController.render()` loads the document, and the
        // titlebar would show the previous filename for that whole time. The
        // subtitle must follow, since its page count comes from that document.
        case .mode:
            synchronizeWindowTitleWithDocumentName()
            contentController.render()
            updateWindowSubtitle()
            // A query typed against the previous document means nothing here.
            toolbar.resetSearch()
            if let selectedPDFURL = session.mode.selectedPDFURL {
                RecentLocationsStore.shared.notePDF(selectedPDFURL)
            }
            invalidateDocumentRestorableState()

        case .history:
            break
        }

        // Every change converges the whole toolbar.
        renderToolbar()
    }

    /// The toolbar's inputs, each read from whichever object owns it. Nothing
    /// is cached, so nothing can be stale.
    private var toolbarState: ToolbarState {
        ToolbarState(
//            hasPDF: session.pdfSession?.hasDocument == true,
            mode: session.pdfSession?.hasDocument == true ? .reading : .browsing,
            canGoBack: session.canGoBack,
            canGoForward: session.canGoForward,
            isActualSizeActive: readerController.isActualSizeActive,
            inspectorSection: contentController.inspectorSection
        )
    }

    /// Installing comes first: the mode decides *which* toolbar is on the
    /// window, and rendering then makes that one match the rest of the state.
    private func renderToolbar() {
        let state = toolbarState
        if let window {
            toolbar.install(for: state.mode, in: window)
        }
        toolbar.render(state)
    }

    /// The document encodes the session's location, so it is the object whose
    /// restorable state goes stale when the session navigates.
    private func invalidateDocumentRestorableState() {
        (document as? NSDocument)?.invalidateRestorableState()
    }

    /// AppKit's hook for pushing document identity into the titlebar, called
    /// whenever `NSDocument.fileURL` changes.
    ///
    /// Overridden because the inherited version points the title and proxy icon
    /// at the document, which here is the workspace folder, not the open PDF.
    /// Without this an AppKit-initiated sync races the session and replaces the
    /// filename with the folder name.
    override func synchronizeWindowTitleWithDocumentName() {
        guard let window else { return }

        let title = session.windowTitle
        if window.title != title {
            window.title = title
        }
        if window.representedURL != session.representedURL {
            window.representedURL = session.representedURL
        }
        updateTitlebarTransparencyAndBlur()
    }

    /// Separate from the title because it changes on every scroll; reassigning
    /// `representedURL` at that rate makes AppKit re-resolve the proxy icon.
    private func updateWindowSubtitle() {
        guard let window else { return }

        let subtitle = session.pdfSession?.hasDocument == true
            ? (readerController.presentationState.pageSummary ?? "")
            : ""
        if window.subtitle != subtitle {
            window.subtitle = subtitle
        }
    }

    /// Transparency and the blur are one decision: the titlebar only goes
    /// transparent where content shows through it, and that is exactly where the
    /// content needs a material of its own.
    @objc private func updateTitlebarTransparencyAndBlur(
        _ notification: Notification? = nil
    ) {
        guard let window else { return }

        let hasTabBar = window.tabGroup?.isTabBarVisible == true
        let hasToolbar = window.toolbar?.isVisible == true
        let hasPDF = session.pdfSession?.hasDocument == true

        // The tab bar always fills the strip itself. A PDF only stays behind an
        // opaque titlebar while the toolbar is up; hide the toolbar and the page
        // runs the full height of the window.
        let shouldBeTransparent = !hasTabBar && !(hasPDF && hasToolbar)
        if window.titlebarAppearsTransparent != shouldBeTransparent {
            window.titlebarAppearsTransparent = shouldBeTransparent
        }

        contentController.setTitlebarBlur(visible: shouldBeTransparent)
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

    @objc func goToLibrary(_ sender: Any?) {
        session.showLibrary()
    }

    @objc func goToStartPage(_ sender: Any?) {
        session.showStartPage()
    }

    @objc func goToEnclosingFolder(_ sender: Any?) {
        session.showEnclosingFolder()
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
        renderToolbar()
    }

    @objc func zoomOut(_ sender: Any?) {
        readerController.zoomOut()
        renderToolbar()
    }

    @objc func showActualSize(_ sender: Any?) {
        readerController.showActualSize()
        renderToolbar()
    }

    @objc func zoomToFit(_ sender: Any?) {
        readerController.zoomToFit()
        renderToolbar()
    }

    @objc func openCurrentPDFInDefaultApp(_ sender: Any?) {
        readerController.openInDefaultApp()
    }

    @objc func shareCurrentPDF(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        readerController.share(from: contentView)
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
        case #selector(goToLibrary(_:)):
            session.canGoToLibrary
        case #selector(goToStartPage(_:)):
            session.canGoToStartPage
        case #selector(goToEnclosingFolder(_:)):
            session.canGoToEnclosingFolder
        case #selector(toggleSidebar(_:)),
             #selector(newTab(_:)),
             #selector(openNewWorkspace(_:)),
             #selector(customizeToolbar(_:)),
             #selector(beginSearch(_:)):
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
        case #selector(selectNextSearchMatch(_:)),
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
