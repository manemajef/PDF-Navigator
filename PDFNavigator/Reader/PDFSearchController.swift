import AppKit
import PDFKit

@MainActor
final class PDFSearchController {
    private weak var pdfView: PDFView?
    private weak var document: PDFDocument?
    private var query = ""
    private var matches: [PDFSelection] = []
    private var selectedMatchIndex: Int?
    private var observers: [NSObjectProtocol] = []

    var hasSearchableDocument: Bool {
        document != nil
    }

    func attach(pdfView: PDFView) {
        self.pdfView = pdfView
        setDocument(pdfView.document)
    }

    func setDocument(_ document: PDFDocument?) {
        clearFindObservers()
        self.document = document
        query = ""
        matches = []
        selectedMatchIndex = nil
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()
    }

    func updateQuery(_ rawQuery: String) {
        let nextQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nextQuery != query else { return }

        clearFindObservers()
        query = nextQuery
        matches = []
        selectedMatchIndex = nil
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()

        guard let document, !nextQuery.isEmpty else { return }

        observeFindNotifications(for: document)
        document.beginFindString(nextQuery, withOptions: .caseInsensitive)
    }

    func selectNextMatch() {
        selectMatch(offset: 1)
    }

    func selectPreviousMatch() {
        selectMatch(offset: -1)
    }

    func clear() {
        clearFindObservers()
        document?.cancelFindString()
        query = ""
        matches = []
        selectedMatchIndex = nil
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()
    }

    private func observeFindNotifications(for document: PDFDocument) {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: .PDFDocumentDidFindMatch,
                object: document,
                queue: .main
            ) { [weak self] notification in
                guard let selection = notification.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection else {
                    return
                }
                Task { @MainActor [weak self, selection] in
                    self?.appendMatch(selection)
                }
            },
            center.addObserver(
                forName: .PDFDocumentDidEndFind,
                object: document,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.clearFindObservers()
                }
            }
        ]
    }

    private func appendMatch(_ selection: PDFSelection) {
        selection.color = .systemYellow.withAlphaComponent(0.45)
        matches.append(selection)
        pdfView?.highlightedSelections = matches

        if selectedMatchIndex == nil {
            selectedMatchIndex = 0
            show(selection)
        }
    }

    private func selectMatch(offset: Int) {
        guard !matches.isEmpty else { return }
        let currentIndex = selectedMatchIndex ?? (offset > 0 ? -1 : matches.count)
        let nextIndex = (currentIndex + offset + matches.count) % matches.count
        selectedMatchIndex = nextIndex
        show(matches[nextIndex])
    }

    private func show(_ selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(nil)
    }

    private func clearFindObservers() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers = []
    }
}
