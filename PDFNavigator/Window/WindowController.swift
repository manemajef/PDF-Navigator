import AppKit
import Combine

final class WindowController: NSWindowController {
    let session = TabSession()
    let actions = WindowActions()

    private lazy var toolbar = WindowToolbar(target: self)
    private lazy var contentController = WindowContentController(
        session: session,
        actions: actions
    )
    private var sessionChangesSubscription: AnyCancellable?

    private var reader: PDFReaderController {
        contentController.readerController
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
        sessionChangesSubscription = session.changes.sink { [weak self] change in
            self?.apply(change)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func open(_ request: OpenRequest) {
        session.open(request)
    }

    private func configureWindow() {
        guard let window else { return }
        window.tabbingIdentifier = "WorkspaceWindow"
        window.tabbingMode = .automatic
        window.toolbarStyle = .unified
        window.autorecalculatesKeyViewLoop = true

        window.toolbar = toolbar.makeToolbar()
        window.contentViewController = contentController

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
            updateWindowIdentity()
            if let root = session.root {
                RecentLocationsStore.shared.noteWorkspace(root)
            }

        case .selection:
            updateWindowIdentity()
            toolbar.updatePDFAvailability(
                session.pdfSession?.hasDocument == true
            )
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
    }

    // MARK: - Commands

    @objc func newTab(_ sender: Any?) {
        actions.newTab()
    }

    @objc func goBack(_ sender: Any?) {
        session.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        session.goForward()
    }

    @objc func toggleSidebar(_ sender: Any?) {
        contentController.toggleSidebar(sender)
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
        reader.goToPreviousPage()
    }

    @objc func goToNextPage(_ sender: Any?) {
        reader.goToNextPage()
    }

    @objc func zoomIn(_ sender: Any?) {
        reader.zoomIn()
    }

    @objc func zoomOut(_ sender: Any?) {
        reader.zoomOut()
    }

    @objc func showActualSize(_ sender: Any?) {
        reader.showActualSize()
    }

    @objc func zoomToFit(_ sender: Any?) {
        reader.zoomToFit()
    }

    @objc func openCurrentPDFInDefaultApp(_ sender: Any?) {
        reader.openInDefaultApp()
    }

    @objc func shareCurrentPDF(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        reader.share(from: contentView)
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
        case #selector(toggleSidebar(_:)),
             #selector(newTab(_:)),
             #selector(customizeToolbar(_:)):
            true
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
            session.pdfSession?.hasDocument == true
        default:
            true
        }
    }
}
