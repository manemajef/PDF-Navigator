import Combine
import PDFKit

@MainActor
final class PDFReaderController: ObservableObject {
    private weak var pdfView: PDFView?
    private weak var searchedDocument: PDFDocument?
    private var searchQuery = ""
    private var searchMatches: [PDFSelection] = []

    func attach(_ pdfView: PDFView) {
        self.pdfView = pdfView
    }

    func detach(_ pdfView: PDFView) {
        guard self.pdfView === pdfView else {
            return
        }

        clearSearch()
        self.pdfView = nil
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

        searchMatches = document.findString(
            query,
            withOptions: .caseInsensitive
        )

        for match in searchMatches {
            match.color = .systemYellow.withAlphaComponent(
                0.45
            )
        }

        pdfView.highlightedSelections = searchMatches

        guard let firstMatch = searchMatches.first else {
            return
        }

        pdfView.setCurrentSelection(
            firstMatch,
            animate: true
        )
        pdfView.scrollSelectionToVisible(nil)
    }

    private func clearSearch() {
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()
        searchedDocument = nil
        searchQuery = ""
        searchMatches = []
    }
}
