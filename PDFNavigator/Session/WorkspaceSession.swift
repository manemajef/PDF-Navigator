import Combine
import Foundation
import Observation

/// The browsing state of one native tab or window.
@MainActor
@Observable
final class WorkspaceSession {
    enum Change: Equatable {
        /// A different workspace is open: the navigator must re-root.
        case workspace
        /// Where this session points changed.
        case mode
        case history
    }

    /// The directory the navigator is rooted at and recents are scoped to.
    ///
    /// Changed only by `open(_:)`. Browsing into a subfolder moves `mode`, not
    /// this: the workspace you chose is not something a click should redefine.
    private(set) var root: URL

    private(set) var mode: WorkspaceMode

    /// Non-`nil` exactly while `mode` is `.reading`, which is what lets the
    /// shell keep asking it whether PDF commands apply.
    private(set) var pdfSession: PDFSession?

    @ObservationIgnored
    private var history = NavigationHistory()

    @ObservationIgnored
    let changes = PassthroughSubject<Change, Never>()

    init(request: OpenRequest) {
        root = request.workspaceRootURL
        mode = request.mode
        pdfSession = request.mode.selectedPDFURL.map(PDFSession.init(url:))
        history.reset(to: request)
    }

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }
    var canGoToLibrary: Bool { mode != .library(root) }

    /// What this session would encode or reopen as.
    var currentRequest: OpenRequest {
        OpenRequest(workspaceRootURL: root, mode: mode)
    }

    /// The file the titlebar proxy icon points at.
    var representedURL: URL {
        switch mode {
        case .startPage: root
        case .library(let url): url
        case .reading(let url): url
        }
    }

    /// `displayName(atPath:)` is what Finder and Preview show: it honours the
    /// user's "Show all filename extensions" setting and localized folder
    /// names, rather than always printing the raw `Foo.pdf`.
    var windowTitle: String {
        let url = representedURL
        let displayName = url.lastPathComponent.isEmpty
            ? url.path
            : FileManager.default.displayName(atPath: url.path)

        return mode == .startPage ? "\(displayName) Recents" : displayName
    }

    // MARK: - Changing workspace

    /// Points this session at a workspace.
    ///
    /// Clears history: the previous workspace's locations are not somewhere
    /// Back should return to. This is the only method that moves `root`.
    func open(_ request: OpenRequest) {
        root = request.workspaceRootURL
        apply(request.mode)
        history.reset(to: request)

        changes.send(.workspace)
        changes.send(.mode)
        changes.send(.history)
    }

    // MARK: - Moving within the workspace

    func select(_ pdfURL: URL) {
        navigate(to: .pdf(pdfURL, in: root))
    }

    func showFolder(_ folderURL: URL) {
        navigate(to: .folder(folderURL, in: root))
    }

    func showLibrary() {
        navigate(to: .folder(root, in: root))
    }

    func goBack() {
        guard let request = history.goBack() else { return }
        move(to: request)
    }

    func goForward() {
        guard let request = history.goForward() else { return }
        move(to: request)
    }

    /// The one path that records a move. Every caller passes `in: root`, so a
    /// navigation can never re-root the workspace behind the navigator's back.
    private func navigate(to request: OpenRequest) {
        guard request != currentRequest else { return }
        history.visit(request)
        move(to: request)
    }

    /// Applies a request already in history, which by construction shares this
    /// session's root — so only `mode` can differ.
    private func move(to request: OpenRequest) {
        apply(request.mode)
        changes.send(.mode)
        changes.send(.history)
    }

    private func apply(_ mode: WorkspaceMode) {
        self.mode = mode
        pdfSession = mode.selectedPDFURL.map(PDFSession.init(url:))
    }
}
