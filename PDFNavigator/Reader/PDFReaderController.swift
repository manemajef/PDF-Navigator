import AppKit
import Combine
import CoreGraphics
import PDFKit

/// Renders a `PDFSession` into a `PDFView`.
final class PDFReaderController: NSViewController {
    private let pdfView = PDFView()

    let presentationState = PDFReaderPresentationState()

    var onZoomStateChange: (() -> Void)?

    private var session: PDFSession?
    private var sessionChangesSubscription: AnyCancellable?
    private var pdfViewObservers: [NSObjectProtocol] = []

    override func loadView() {
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
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

        pdfView.autoScales = true
        pdfView.document = session.document
        pdfView.highlightedSelections = nil
        pdfView.clearSelection()
        restorePosition(from: session)
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

    private func updatePresentationState() {
        let currentPageIndex: Int?

        if let document = pdfView.document,
           let page = pdfView.currentPage {
            let index = document.index(for: page)
            currentPageIndex = index == NSNotFound ? nil : index
        } else {
            currentPageIndex = nil
        }

        presentationState.update(
            currentPageIndex: currentPageIndex,
            scaleFactor: pdfView.scaleFactor,
            isZoomToFit: pdfView.autoScales
        )
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
