import AppKit
import Combine
import Observation
import PDFKit

/// Everything true about one open PDF.
///
/// This is the single source of truth for the reader. `PDFReaderController`
/// owns a `PDFView` and renders whatever this object says; it stores no
/// document state of its own.
///
/// Future semantic PDF tools (highlights, bookmarks, annotations) become
/// properties and methods here. Read-only PDFKit data such as pages, outlines,
/// and metadata can be derived from `document` without copying it into state.
/// `Change` remains only as the narrow bridge for imperative updates that
/// `PDFView` must apply.

@Observable
final class PDFSession {
    enum Change {
        case searchQuery
        case matchesFinalized
        case currentMatch
    }

    let url: URL
    private(set) var document: PDFDocument?

    private(set) var searchQuery = ""
    private(set) var matches: [PDFSelection] = []
    private(set) var currentMatchIndex: Int?

    @ObservationIgnored
    let changes = PassthroughSubject<Change, Never>()

    @ObservationIgnored
    private var findObservers: [NSObjectProtocol] = []
    @ObservationIgnored
    private let positions = ReadingPositionStore()

    var hasDocument: Bool {
        document != nil
    }

    var currentMatch: PDFSelection? {
        guard let currentMatchIndex,
              matches.indices.contains(currentMatchIndex) else {
            return nil
        }
        return matches[currentMatchIndex]
    }

    init(url: URL) {
        self.url = url.standardizedFileURL
        load()
    }

    deinit {
        document?.cancelFindString()
        for observer in findObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Loading

    private func load() {
        guard let document = PDFDocument(url: url) else { return }

        for pageIndex in 0..<document.pageCount {
            document.page(at: pageIndex)?.annotations.forEach {
                $0.isReadOnly = true
            }
        }

        self.document = document
    }

    // MARK: - Reading position

    var savedPosition: ReadingPosition? {
        positions.position(for: url)
    }

    func savePosition(_ position: ReadingPosition) {
        positions.save(position, for: url)
    }

    // MARK: - Search

    func search(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != searchQuery else { return }

        cancelFind()

        searchQuery = query
        matches = []
        currentMatchIndex = nil
        changes.send(.searchQuery)

        guard let document, !query.isEmpty else { return }

        observeFind(for: document)
        document.beginFindString(query, withOptions: .caseInsensitive)
    }

    func selectNextMatch() {
        selectMatch(offset: 1)
    }

    func selectPreviousMatch() {
        selectMatch(offset: -1)
    }

    private func selectMatch(offset: Int) {
        guard !matches.isEmpty else { return }
        let current = currentMatchIndex ?? (offset > 0 ? -1 : matches.count)
        currentMatchIndex = (current + offset + matches.count) % matches.count
        changes.send(.currentMatch)
    }

    private func observeFind(for document: PDFDocument) {
        let center = NotificationCenter.default

        findObservers = [
            center.addObserver(
                forName: .PDFDocumentDidFindMatch,
                object: document,
                queue: .main
            ) { [weak self] notification in
                guard let selection =
                    notification.userInfo?[PDFDocumentFoundSelectionKey]
                        as? PDFSelection
                else {
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
                    self?.finishFind()
                }
            }
        ]
    }

    private func appendMatch(_ selection: PDFSelection) {
        selection.color = .systemYellow.withAlphaComponent(0.45)
        matches.append(selection)

        // Only the first result moves the PDF view. Sending an event for
        // every result could make the view scroll thousands of times.
        if currentMatchIndex == nil {
            currentMatchIndex = 0
            changes.send(.currentMatch)
        }
    }

    private func finishFind() {
        clearFindObservers()
        changes.send(.matchesFinalized)
    }

    private func cancelFind() {
        document?.cancelFindString()
        clearFindObservers()
    }

    private func clearFindObservers() {
        let center = NotificationCenter.default

        for observer in findObservers {
            center.removeObserver(observer)
        }

        findObservers = []
    }
}
