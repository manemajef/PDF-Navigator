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
    var canGoToStartPage: Bool { mode != .startPage }
    var canGoToEnclosingFolder: Bool { enclosingFolderURL != nil }

    /// The folder one level up from where this session points, or `nil` when there is nowhere above to go.
    /// The command's availability is this being non-`nil`, so the rule is stated once and both the menu item and the move read it from here.
    /// `root` is the ceiling. Browsing must not be able to walk a session out of the workspace the user chose, and `deletingLastPathComponent()` will happily do exactly that.
    var enclosingFolderURL: URL? {
        let candidate: URL

        switch mode {
        // Recents is scoped to the whole workspace, so no one folder encloses it.
        case .startPage:
            return nil

        /// Showing the root already: there is nothing left to go up to. This is the only case where being at the root disables the command.
        case .library(let folderURL):
            guard folderURL != root else { return nil }
            candidate = folderURL.deletingLastPathComponent()

        case .reading(let pdfURL):
            candidate = pdfURL.deletingLastPathComponent()
        }

        guard candidate.isDescendantOrSame(of: root) else { return nil }
        return candidate
    }

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

    ///`displayName(atPath:)` honours the user's "Show all filename extensions" setting and localized folder
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

    func show(_ pdfURL: URL) {
        navigate(to: .pdf(pdfURL, in: root))
    }

    func showFolder(_ folderURL: URL) {
        navigate(to: .folder(folderURL, in: root))
    }

    func showLibrary() {
        navigate(to: .folder(root, in: root))
    }

    /// The workspace's recents, which `WorkspaceMode` calls the start page.
    func showStartPage() {
        navigate(to: .startPage(in: root))
    }

    /// Routed through `showFolder(_:)` rather than `navigate(to:)`, so going up
    /// is recorded in history exactly like any other folder click.
    func showEnclosingFolder() {
        guard let enclosingFolderURL else { return }
        showFolder(enclosingFolderURL)
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
