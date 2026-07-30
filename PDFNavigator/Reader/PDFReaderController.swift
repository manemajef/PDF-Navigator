import AppKit
import PDFKit

final class PDFReaderController: NSViewController {
    private let pdfView = PDFView()
    private let searchController = PDFSearchController()
    private let positions = ReadingPositionStore()
    private var currentURL: URL?

    var currentPDFURL: URL? {
        currentURL
    }

    var hasDocument: Bool {
        pdfView.document != nil
    }

    override func loadView() {
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.displayBox = .cropBox
        pdfView.autoScales = true
        searchController.attach(pdfView: pdfView)
        view = pdfView
    }

    func display(_ url: URL) {
        loadViewIfNeeded()
        let url = url.standardizedFileURL
        guard currentURL != url else { return }

        savePosition()
        currentURL = url

        guard let document = PDFDocument(url: url) else {
            pdfView.document = nil
            return
        }

        for pageIndex in 0..<document.pageCount {
            document.page(at: pageIndex)?.annotations.forEach {
                $0.isReadOnly = true
            }
        }

        pdfView.autoScales = true
        pdfView.document = document
        searchController.setDocument(document)
        restorePosition(for: url, in: document)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        savePosition()
    }

    func search(_ query: String) {
        searchController.updateQuery(query)
    }

    func selectNextSearchMatch() {
        searchController.selectNextMatch()
    }

    func selectPreviousSearchMatch() {
        searchController.selectPreviousMatch()
    }

    func goToPreviousPage() {
        pdfView.goToPreviousPage(nil)
    }

    func goToNextPage() {
        pdfView.goToNextPage(nil)
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
    }

    func openInDefaultApp() {
        guard let currentURL else { return }
        NSWorkspace.shared.open(currentURL)
    }

    func share(from sourceView: NSView) {
        guard let currentURL else { return }
        NSSharingServicePicker(items: [currentURL]).show(
            relativeTo: sourceView.bounds,
            of: sourceView,
            preferredEdge: .maxY
        )
    }

    private func restorePosition(for url: URL, in document: PDFDocument) {
        guard let position = positions.position(for: url),
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
        guard let currentURL,
              let document = pdfView.document,
              let destination = pdfView.currentDestination,
              let page = destination.page else {
            return
        }

        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else { return }

        positions.save(
            ReadingPosition(
                pageIndex: pageIndex,
                pointX: destination.point.x,
                pointY: destination.point.y,
                zoom: pdfView.scaleFactor
            ),
            for: currentURL
        )
    }
}
