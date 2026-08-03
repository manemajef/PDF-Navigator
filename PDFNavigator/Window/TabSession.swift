import Combine
import Foundation

/// The browsing state of one native tab or window.
final class TabSession {
    enum Mode: Equatable {
        case welcome
        case workspaceHome(URL)
        case reading(URL)
    }

    enum Change: Equatable {
        case root
        case selection
        case history
    }

    private(set) var root: URL?
    private(set) var selection: URL?
    private(set) var pdfSession: PDFSession?

    private var history = NavigationHistory()

    let changes = PassthroughSubject<Change, Never>()

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }

    var mode: Mode {
        if let selection {
            return .reading(selection)
        }
        if let root {
            return .workspaceHome(root)
        }
        return .welcome
    }

    var windowTitle: String {
        if let selection {
            return selection.lastPathComponent
        }
        if let root {
            return root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent
        }
        return "PDF Navigator"
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
