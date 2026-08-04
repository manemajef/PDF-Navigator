import AppKit
import Combine
import SwiftUI

final class WindowController: NSWindowController {
    let session: TabSession
    let actions = WindowActions()

    private let presentation = WorkspacePresentation()
    private let readerController = PDFReaderController()
    private var sessionChangesSubscription: AnyCancellable?

    private lazy var commands = WindowCommands(
        chooseLocation: { [weak actions] in actions?.chooseLocation() },
        openPDF: { [weak actions] in actions?.openPDF($0) },
        openInNewTab: { [weak actions] in actions?.openInNewTab($0, $1) },
        newTab: { [weak actions] in actions?.newTab($0) },
        revealInFinder: {
            NSWorkspace.shared.activateFileViewerSelecting([$0])
        },
        goToPreviousPage: { [weak readerController] in
            readerController?.goToPreviousPage()
        },
        goToNextPage: { [weak readerController] in
            readerController?.goToNextPage()
        },
        zoomIn: { [weak readerController] in readerController?.zoomIn() },
        zoomOut: { [weak readerController] in readerController?.zoomOut() },
        showActualSize: { [weak readerController] in
            readerController?.showActualSize()
        },
        zoomToFit: { [weak readerController] in readerController?.zoomToFit() },
        openCurrentPDFInDefaultApp: { [weak readerController] in
            readerController?.openInDefaultApp()
        },
        shareCurrentPDF: { [weak self] in
            guard let self, let contentView = window?.contentView else { return }
            readerController.share(from: contentView)
        }
    )

    private lazy var contentController: NSHostingController<WorkspaceView> = {
        let controller = NSHostingController(
            rootView: WorkspaceView(
                session: session,
                presentation: presentation,
                commands: commands,
                readerController: readerController
            )
        )
        controller.sceneBridgingOptions = [.toolbars]
        return controller
    }()

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

    private func configureWindow() {
        guard let window else { return }
        window.tabbingIdentifier = "WorkspaceWindow"
        window.tabbingMode = .automatic
        window.toolbarStyle = .unified
        window.autorecalculatesKeyViewLoop = true

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
            RecentLocationsStore.shared.noteWorkspace(session.root)

        case .selection:
            updateWindowIdentity()
            if let selection = session.selection {
                RecentLocationsStore.shared.notePDF(selection)
            }

        case .history:
            break
        }
    }

    private func updateWindowIdentity() {
        window?.title = session.windowTitle
        window?.representedURL = session.representedURL
    }

    // MARK: - Commands

    @objc func newTab(_ sender: Any?) {
        actions.newTab(.foreground)
    }

    @objc func goBack(_ sender: Any?) {
        session.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        session.goForward()
    }

    @objc func toggleSidebar(_ sender: Any?) {
        presentation.toggleSidebar()
    }

    @objc func beginSearch(_ sender: Any?) {
        presentation.isSearchPresented = true
    }

    func endSearchInteraction() {
        presentation.isSearchPresented = false
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
    }

    @objc func zoomOut(_ sender: Any?) {
        readerController.zoomOut()
    }

    @objc func showActualSize(_ sender: Any?) {
        readerController.showActualSize()
    }

    @objc func zoomToFit(_ sender: Any?) {
        readerController.zoomToFit()
    }

    @objc func openCurrentPDFInDefaultApp(_ sender: Any?) {
        readerController.openInDefaultApp()
    }

    @objc func shareCurrentPDF(_ sender: Any?) {
        guard let contentView = window?.contentView else { return }
        readerController.share(from: contentView)
    }
}

extension WindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        canPerform(menuItem.action)
    }

    private func canPerform(_ action: Selector?) -> Bool {
        switch action {
        case #selector(goBack(_:)):
            session.canGoBack
        case #selector(goForward(_:)):
            session.canGoForward
        case #selector(toggleSidebar(_:)),
             #selector(newTab(_:)):
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
