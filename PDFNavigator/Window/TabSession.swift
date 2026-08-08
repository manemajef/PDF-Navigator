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
        history.reset(to: request)
    }

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }
    var canGoToWorkspaceHome: Bool { selection != nil }

    var mode: Mode {
        if let selection {
            return .reading(selection)
        }
        return .workspaceHome(root)
    }

    /// `displayName(atPath:)` is what Finder and Preview show: it honours the
    /// user's "Show all filename extensions" setting and localized folder
    /// names, rather than always printing the raw `Foo.pdf`.
    var windowTitle: String {
        if let selection {
            return FileManager.default.displayName(atPath: selection.path)
        }
        guard !root.lastPathComponent.isEmpty else { return root.path }
        return FileManager.default.displayName(atPath: root.path)
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
        history.reset(to: request)

        changes.send(.root)
        changes.send(.selection)
        changes.send(.history)
    }

    func select(_ url: URL) {
        let url = url.standardizedFileURL
        guard selection != url else { return }

        selection = url
        pdfSession = PDFSession(url: url)
        history.visit(.pdf(url, in: root))

        changes.send(.selection)
        changes.send(.history)
    }

    func goToWorkspaceHome() {
        navigate(to: .folder(root))
    }

    func goBack() {
        guard let request = history.goBack() else { return }
        apply(request)
    }

    func goForward() {
        guard let request = history.goForward() else { return }
        apply(request)
    }

    private func navigate(to request: OpenRequest) {
        let currentRequest = OpenRequest(
            workspaceRootURL: root,
            selectedPDFURL: selection
        )
        guard request != currentRequest else { return }
        history.visit(request)
        apply(request)
    }

    private func apply(_ request: OpenRequest) {
        let rootChanged = root != request.workspaceRootURL
        root = request.workspaceRootURL
        selection = request.selectedPDFURL
        pdfSession = selection.map(PDFSession.init(url:))

        if rootChanged {
            changes.send(.root)
        }
        changes.send(.selection)
        changes.send(.history)
    }
}
