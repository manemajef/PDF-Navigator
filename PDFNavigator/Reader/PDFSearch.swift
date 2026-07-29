import Combine
import PDFKit

@MainActor
final class PDFSearch {
    private weak var document: PDFDocument?
    private weak var view: PDFView?
    private var query = ""
    private var matches: [PDFSelection] = []
    private var observations: Set<AnyCancellable> = []

    func update(_ text: String, in view: PDFView) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != self.query || document !== view.document else { return }

        clear()
        guard let document = view.document, !query.isEmpty else { return }

        self.query = query
        self.document = document
        self.view = view

        NotificationCenter.default.publisher(
            for: .PDFDocumentDidFindMatch,
            object: document
        )
        .compactMap {
            $0.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection
        }
        .sink { [weak self] in self?.add($0) }
        .store(in: &observations)

        NotificationCenter.default.publisher(
            for: .PDFDocumentDidEndFind,
            object: document
        )
        .sink { [weak self] _ in self?.observations.removeAll() }
        .store(in: &observations)

        document.beginFindString(query, withOptions: .caseInsensitive)
    }

    func selectMatch(backward: Bool) {
        guard let document, let view, !query.isEmpty else { return }

        let options: NSString.CompareOptions = backward ? [.caseInsensitive, .backwards] : .caseInsensitive
        let selection = document.findString(
            query,
            fromSelection: view.currentSelection,
            withOptions: options
        ) ?? document.findString(
            query,
            fromSelection: nil,
            withOptions: options
        )
        guard let selection else { return }

        view.setCurrentSelection(selection, animate: true)
        view.scrollSelectionToVisible(nil)
    }

    func clear() {
        document?.cancelFindString()
        observations.removeAll()
        view?.highlightedSelections = nil
        view?.clearSelection()
        document = nil
        view = nil
        query = ""
        matches = []
    }

    private func add(_ selection: PDFSelection) {
        selection.color = .systemYellow.withAlphaComponent(0.45)
        matches.append(selection)
        view?.highlightedSelections = matches

        if matches.count == 1 {
            view?.setCurrentSelection(selection, animate: true)
            view?.scrollSelectionToVisible(nil)
        }
    }
}
