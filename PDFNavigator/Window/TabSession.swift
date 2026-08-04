import Combine
import Foundation
import Observation

/// The browsing state of one native tab or window.
@MainActor
@Observable
final class TabSession {
    enum Mode: Equatable {
        case workspaceHome(URL)
        case reading(URL)
    }

    enum Change: Equatable {
        case root
        case selection
        case history
    }

    private(set) var root: URL
    private(set) var selection: URL?
    private(set) var pdfSession: PDFSession?

    @ObservationIgnored
    private var history = NavigationHistory()

    @ObservationIgnored
    let changes = PassthroughSubject<Change, Never>()

    init(request: OpenRequest) {
        root = request.workspaceRootURL
        selection = request.selectedPDFURL
        if let selection {
            pdfSession = PDFSession(url: selection)
        } else {
            pdfSession = nil
        }
        history.reset(to: selection)
    }

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }

    var mode: Mode {
        if let selection {
            return .reading(selection)
        }
        return .workspaceHome(root)
    }

    var windowTitle: String {
        if let selection {
            return selection.lastPathComponent
        }
        return root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent
    }

    var representedURL: URL? {
        selection ?? root
    }

    func open(_ request: OpenRequest) {
        root = request.workspaceRootURL
        selection = request.selectedPDFURL
        if let selection {
            pdfSession = PDFSession(url: selection)
        } else {
            pdfSession = nil
        }
        history.reset(to: selection)

        changes.send(.root)
        changes.send(.selection)
        changes.send(.history)
    }

    func select(_ url: URL) {
        let url = url.standardizedFileURL
        guard selection != url else { return }

        selection = url
        pdfSession = PDFSession(url: url)
        history.visit(url)

        changes.send(.selection)
        changes.send(.history)
    }

    func goBack() {
        guard let url = history.goBack() else { return }
        applyHistorySelection(url)
    }

    func goForward() {
        guard let url = history.goForward() else { return }
        applyHistorySelection(url)
    }

    private func applyHistorySelection(_ url: URL) {
        let url = url.standardizedFileURL
        selection = url
        pdfSession = PDFSession(url: url)

        changes.send(.selection)
        changes.send(.history)
    }
}
