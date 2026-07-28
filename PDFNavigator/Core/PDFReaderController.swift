import Combine
import PDFKit

struct PDFReaderCapabilities {
    var canGoToPreviousPage = false
    var canGoToNextPage = false
    var canGoBack = false
    var canGoForward = false
    var canZoomIn = false
    var canZoomOut = false
    var hasDocument = false
}

@MainActor
final class PDFReaderController: ObservableObject {
    @Published private(set) var capabilities =
        PDFReaderCapabilities()

    private weak var pdfView: PDFView?
    private var currentURL: URL?
    private weak var searchedDocument: PDFDocument?
    private var searchQuery = ""
    private var searchMatches: [PDFSelection] = []
    private var viewObservations: Set<AnyCancellable> = []
    private var searchObservations: Set<AnyCancellable> = []
    private var positionSaveTask: Task<Void, Never>?
    private let documentCache = NSCache<NSURL, PDFDocument>()
    private let positionStore = ReadingPositionStore()

    init() {
        documentCache.countLimit = 3
    }

    deinit {
        positionSaveTask?.cancel()
    }

    func attach(
        _ pdfView: PDFView,
        url: URL
    ) {
        if self.pdfView !== pdfView {
            self.pdfView = pdfView
            observe(pdfView)
        }

        currentURL = url
        updateCapabilities()
    }

    func detach(_ pdfView: PDFView) {
        guard self.pdfView === pdfView else {
            return
        }

        saveReadingPosition()
        clearSearch()
        viewObservations.removeAll()
        self.pdfView = nil
        currentURL = nil
        updateCapabilities()
    }

    func document(for url: URL) -> PDFDocument? {
        let key = url.standardizedFileURL as NSURL
        if let cached = documentCache.object(forKey: key) {
            return cached
        }

        guard let document = PDFDocument(url: url) else {
            return nil
        }

        documentCache.setObject(document, forKey: key)
        prepareReadOnlyAnnotations(in: document)
        return document
    }

    func position(for url: URL) -> ReadingPosition? {
        positionStore.position(for: url)
    }

    func willDisplayDocument(at url: URL) {
        if currentURL != url {
            saveReadingPosition()
            clearSearch()
        }
    }

    func search(for text: String) {
        let query = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            let pdfView,
            let document = pdfView.document
        else {
            clearSearch()
            return
        }

        guard
            query != searchQuery
                || searchedDocument !== document
        else {
            return
        }

        clearSearch()
        searchQuery = query
        searchedDocument = document

        guard !query.isEmpty else {
            return
        }

        observeSearch(in: document)
        document.beginFindString(
            query,
            withOptions: .caseInsensitive
        )
    }

    func goToPreviousPage() {
        pdfView?.goToPreviousPage(nil)
    }

    func goToNextPage() {
        pdfView?.goToNextPage(nil)
    }

    func goBack() {
        pdfView?.goBack(nil)
    }

    func goForward() {
        pdfView?.goForward(nil)
    }

    func zoomIn() {
        pdfView?.zoomIn(nil)
    }

    func zoomOut() {
        pdfView?.zoomOut(nil)
    }

    func showActualSize() {
        pdfView?.autoScales = false
        pdfView?.scaleFactor = 1
    }

    func zoomToFit() {
        guard let pdfView else {
            return
        }

        pdfView.autoScales = false
        pdfView.scaleFactor =
            pdfView.scaleFactorForSizeToFit
    }

    private func observe(_ pdfView: PDFView) {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .PDFViewChangedHistory,
            .PDFViewDocumentChanged,
            .PDFViewPageChanged,
            .PDFViewScaleChanged,
            .PDFViewVisiblePagesChanged
        ]

        for name in names {
            center.publisher(for: name, object: pdfView)
                .sink { [weak self] _ in
                    self?.pdfViewDidChange()
                }
                .store(in: &viewObservations)
        }
    }

    private func observeSearch(
        in document: PDFDocument
    ) {
        let center = NotificationCenter.default

        center.publisher(
            for: .PDFDocumentDidFindMatch,
            object: document
        )
        .compactMap { notification in
            notification.userInfo?[
                "PDFDocumentFoundSelection"
            ] as? PDFSelection
        }
        .sink { [weak self] selection in
            self?.addSearchMatch(selection)
        }
        .store(in: &searchObservations)

        center.publisher(
            for: .PDFDocumentDidEndFind,
            object: document
        )
        .sink { [weak self] _ in
            self?.searchObservations.removeAll()
        }
        .store(in: &searchObservations)
    }

    private func addSearchMatch(
        _ selection: PDFSelection
    ) {
        selection.color = .systemYellow
            .withAlphaComponent(0.45)
        searchMatches.append(selection)
        pdfView?.highlightedSelections = searchMatches

        guard searchMatches.count == 1 else {
            return
        }

        pdfView?.setCurrentSelection(
            selection,
            animate: true
        )
        pdfView?.scrollSelectionToVisible(nil)
    }

    private func clearSearch() {
        searchedDocument?.cancelFindString()
        searchObservations.removeAll()
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()
        searchedDocument = nil
        searchQuery = ""
        searchMatches = []
    }

    private func pdfViewDidChange() {
        updateCapabilities()
        schedulePositionSave()
    }

    private func updateCapabilities() {
        guard let pdfView else {
            capabilities = PDFReaderCapabilities()
            return
        }

        capabilities = PDFReaderCapabilities(
            canGoToPreviousPage:
                pdfView.canGoToPreviousPage,
            canGoToNextPage: pdfView.canGoToNextPage,
            canGoBack: pdfView.canGoBack,
            canGoForward: pdfView.canGoForward,
            canZoomIn: pdfView.canZoomIn,
            canZoomOut: pdfView.canZoomOut,
            hasDocument: pdfView.document != nil
        )
    }

    private func schedulePositionSave() {
        positionSaveTask?.cancel()
        positionSaveTask = Task { [weak self] in
            try? await Task.sleep(
                for: .milliseconds(350)
            )

            guard !Task.isCancelled else {
                return
            }

            self?.saveReadingPosition()
        }
    }

    private func saveReadingPosition() {
        guard
            let pdfView,
            let url = currentURL,
            let document = pdfView.document,
            let destination = pdfView.currentDestination,
            let page = destination.page
        else {
            return
        }

        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else {
            return
        }

        positionStore.save(
            ReadingPosition(
                pageIndex: pageIndex,
                pointX: destination.point.x,
                pointY: destination.point.y,
                scaleFactor: pdfView.scaleFactor
            ),
            for: url
        )
    }

    private func prepareReadOnlyAnnotations(
        in document: PDFDocument
    ) {
        Task { [weak document] in
            await Task.yield()

            guard let document else {
                return
            }

            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(
                    at: pageIndex
                ) else {
                    continue
                }

                for annotation in page.annotations {
                    annotation.isReadOnly = true
                }

                await Task.yield()
            }
        }
    }
}
