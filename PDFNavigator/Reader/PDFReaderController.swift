import AppKit
import Combine
import CoreGraphics
import PDFKit

/// Renders a `PDFSession` into a `PDFView`.
final class PDFReaderController: NSViewController {
    private let pdfView = PDFView()

    let presentationState = PDFReaderPresentationState()

    var onZoomStateChange: (() -> Void)?
    var onPageChange: (() -> Void)?

    private var session: PDFSession?
    private var isInstallingDocument = false
    private var sessionChangesSubscription: AnyCancellable?
    private var pdfViewObservers: [NSObjectProtocol] = []

    override func loadView() {
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        pdfView.displayBox = .cropBox
        pdfView.autoScales = true
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        observePDFViewChanges()
        view = pdfView
    }

    deinit {
        for observer in pdfViewObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func display(_ session: PDFSession) {
        loadViewIfNeeded()
        guard self.session !== session else { return }

        savePosition()
        self.session = session
        observe(session)

        isInstallingDocument = true
        pdfView.autoScales = true
        pdfView.document = session.document
        pdfView.highlightedSelections = nil
        pdfView.clearSelection()
        restorePosition(from: session)
        isInstallingDocument = false
        updatePresentationState()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        savePosition()
    }

    private func observe(_ session: PDFSession) {
        sessionChangesSubscription = session.changes.sink { [weak self, weak session] change in
            guard let self, let session,
                  self.session === session else {
                return
            }
            self.render(change, from: session)
        }
    }

    private func observePDFViewChanges() {
        let center = NotificationCenter.default

        pdfViewObservers = [
            center.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.updatePresentationState()
            },
            center.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.updatePresentationState()
                self?.onZoomStateChange?()
            },
            center.addObserver(
                forName: NSScrollView.willStartLiveMagnifyNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let scrollView = notification.object as? NSScrollView,
                      scrollView === pdfView.documentView?.enclosingScrollView
                else {
                    return
                }

                pdfView.autoScales = false
                updatePresentationState()
                onZoomStateChange?()
            },
            // `PDFViewPageChanged` only fires once PDFKit's own notion of the
            // current page flips, which trails the scroll. Watching the clip
            // view directly is what makes the page track the way Preview's
            // does. Registered against `nil` and filtered by identity because
            // the document view does not exist until a document is set.
            center.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let clipView = notification.object as? NSClipView,
                      clipView === pdfView.documentView?.enclosingScrollView?.contentView
                else {
                    return
                }

                updatePresentationState()
            }
        ]
    }

    private func render(_ change: PDFSession.Change, from session: PDFSession) {
        switch change {
        case .searchQuery:
            pdfView.highlightedSelections = nil
            pdfView.clearSelection()

        case .matchesFinalized:
            pdfView.highlightedSelections = session.matches.isEmpty
                ? nil
                : session.matches

        case .currentMatch:
            guard let match = session.currentMatch else {
                pdfView.clearSelection()
                return
            }
            pdfView.setCurrentSelection(match, animate: true)
            pdfView.scrollSelectionToVisible(nil)
        }
    }

    func goToPreviousPage() {
        pdfView.goToPreviousPage(nil)
    }

    func goToNextPage() {
        pdfView.goToNextPage(nil)
    }

    func goToPage(at pageIndex: Int) {
        guard let page = pdfView.document?.page(at: pageIndex) else { return }
        pdfView.go(to: page)
    }

    func follow(_ outline: PDFOutline) {
        if let destination = outline.destination {
            pdfView.go(to: destination)
        } else if let action = outline.action {
            pdfView.perform(action)
        }
    }

    func zoomIn() {
        pdfView.autoScales = false
        pdfView.zoomIn(nil)
    }

    func zoomOut() {
        pdfView.autoScales = false
        pdfView.zoomOut(nil)
    }

    func showActualSize() {
        pdfView.showPrintSize()
    }

    func zoomToFit() {
        pdfView.autoScales = true
        updatePresentationState()
    }

    var isZoomToFitActive: Bool {
        pdfView.autoScales
    }

    var isActualSizeActive: Bool {
        !pdfView.autoScales && abs(pdfView.scaleFactor - pdfView.printSizeScaleFactor) < 0.001
    }

    func openInDefaultApp() {
        guard let session else { return }
        NSWorkspace.shared.open(session.url)
    }

    func share(from sourceView: NSView) {
        guard let session else { return }
        NSSharingServicePicker(items: [session.url]).show(
            relativeTo: sourceView.bounds,
            of: sourceView,
            preferredEdge: .maxY
        )
    }

    private func restorePosition(from session: PDFSession) {
        guard let document = session.document,
              let position = session.savedPosition,
              let page = document.page(at: position.pageIndex) else {
            return
        }

        let destination = PDFDestination(
            page: page,
            at: CGPoint(x: position.pointX, y: position.pointY)
        )
        destination.zoom = position.zoom
        pdfView.go(to: destination)
        pdfView.autoScales = true
    }

    private func savePosition() {
        guard let session,
              let document = session.document,
              let destination = pdfView.currentDestination,
              let page = destination.page else {
            return
        }

        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else { return }

        session.savePosition(
            ReadingPosition(
                pageIndex: pageIndex,
                pointX: destination.point.x,
                pointY: destination.point.y,
                zoom: pdfView.scaleFactor
            )
        )
    }

    /// The one place the reader's live state is derived. Both the inspector and
    /// the window subtitle read the result, so they can never disagree.
    private func updatePresentationState() {
        // Setting `pdfView.document` posts page and bounds notifications
        // synchronously, while `currentPage` can still belong to the outgoing
        // document — publishing a page number that matches neither. `display`
        // calls this once the swap has settled.
        guard !isInstallingDocument else { return }

        let document = pdfView.document
        let currentPageIndex: Int?

        if let document, let page = pdfView.currentPage {
            let index = document.index(for: page)
            currentPageIndex = index == NSNotFound ? nil : index
        } else {
            currentPageIndex = nil
        }

        presentationState.update(
            currentPageIndex: currentPageIndex,
            pageCount: document?.pageCount ?? 0,
            scaleFactor: pdfView.scaleFactor,
            isZoomToFit: pdfView.autoScales
        )
        onPageChange?()
    }
}

private extension PDFView {
    func showPrintSize() {
        autoScales = false
        scaleFactor = printSizeScaleFactor
    }

    var printSizeScaleFactor: CGFloat {
        guard let screen = window?.screen ?? NSScreen.main,
              let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? CGDirectDisplayID else {
            return 1
        }

        let physicalWidth = CGDisplayScreenSize(displayID).width
        guard physicalWidth > 0 else { return 1 }

        return screen.frame.width / (physicalWidth / 25.4) / 72
    }
}
