import Combine
import Foundation

@MainActor
final class WorkspaceSession: ObservableObject {
    enum State {
        case empty
        case loading(rootURL: URL)
        case active(Workspace)
        case failed(rootURL: URL?, message: String)
    }

    struct Workspace {
        let rootURL: URL
        var nodes: [PDFTreeNode]
        var selectedPDF: URL?
    }

    @Published private(set) var state: State = .empty
    @Published private(set) var presentedError: String?

    private var navigationHistory = NavigationHistory()
    private var scanTask: Task<Void, Never>?
    private var workspaceGeneration = UUID()
    private var securityScopedURL: URL?

    init(
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        selectsInitialPDF: Bool = true
    ) {
        if let initialWorkspace {
            open(
                folder: initialWorkspace,
                initialPDF: initialPDF,
                selectsFirstPDF: selectsInitialPDF
            )
        } else if let initialPDF {
            open(pdf: initialPDF)
        }
    }

    deinit {
        scanTask?.cancel()
        securityScopedURL?
            .stopAccessingSecurityScopedResource()
    }

    var navigatorNodes: [PDFTreeNode] {
        activeWorkspace?.nodes ?? []
    }

    var selectedPDF: URL? {
        activeWorkspace?.selectedPDF
    }

    var workspaceURL: URL? {
        switch state {
        case .empty:
            nil
        case .loading(let rootURL):
            rootURL
        case .active(let workspace):
            workspace.rootURL
        case .failed(let rootURL, _):
            rootURL
        }
    }

    var folderName: String {
        guard let workspaceURL else {
            return "PDFs"
        }

        return workspaceURL.lastPathComponent.isEmpty
            ? workspaceURL.path
            : workspaceURL.lastPathComponent
    }

    var canGoBack: Bool {
        navigationHistory.canGoBack
    }

    var canGoForward: Bool {
        navigationHistory.canGoForward
    }

    func select(pdf: URL) {
        guard
            var workspace = activeWorkspace,
            isPDF(pdf, inside: workspace.rootURL)
        else {
            return
        }

        navigationHistory.visit(pdf)
        workspace.selectedPDF = pdf
        state = .active(workspace)

        if workspace.nodes.node(matching: pdf) == nil {
            reveal(pdf, in: workspace)
        }
    }

    func expand(directory: URL) {
        guard
            var workspace = activeWorkspace,
            directory != workspace.rootURL,
            isDescendant(directory, of: workspace.rootURL),
            workspace.nodes.directoryContents(
                at: directory
            ) == .unloaded
        else {
            return
        }

        workspace.nodes =
            workspace.nodes.replacingDirectoryContents(
            at: directory,
            with: .loading,
        )
        state = .active(workspace)

        let generation = workspaceGeneration
        Task { [weak self] in
            do {
                let children = try await
                    PDFDirectoryScanner.scan(
                        directory: directory
                    )
                self?.finishExpansion(
                    directory: directory,
                    children: children,
                    generation: generation
                )
            } catch is CancellationError {
                return
            } catch {
                self?.failExpansion(
                    directory: directory,
                    generation: generation
                )
            }
        }
    }

    func goBack() {
        guard
            let pdf = navigationHistory.goBack(),
            var workspace = activeWorkspace
        else {
            return
        }

        workspace.selectedPDF = pdf
        state = .active(workspace)
    }

    func goForward() {
        guard
            let pdf = navigationHistory.goForward(),
            var workspace = activeWorkspace
        else {
            return
        }

        workspace.selectedPDF = pdf
        state = .active(workspace)
    }

    func open(pdf: URL) {
        open(
            folder: pdf.deletingLastPathComponent(),
            initialPDF: pdf,
            selectsFirstPDF: true
        )
    }

    func open(folder: URL) {
        open(
            folder: folder,
            initialPDF: nil,
            selectsFirstPDF: true
        )
    }

    func report(_ error: Error) {
        presentedError = error.localizedDescription
    }

    func dismissError() {
        presentedError = nil
    }

    private var activeWorkspace: Workspace? {
        guard case .active(let workspace) = state else {
            return nil
        }

        return workspace
    }

    private func open(
        folder: URL,
        initialPDF: URL?,
        selectsFirstPDF: Bool
    ) {
        scanTask?.cancel()
        stopAccessingWorkspace()

        let rootURL = folder.standardizedFileURL
        let selectedPDF = initialPDF?
            .standardizedFileURL
        let validInitialPDF = selectedPDF.flatMap { pdf in
            isPDF(pdf, inside: rootURL) ? pdf : nil
        }
        let generation = UUID()
        workspaceGeneration = generation
        state = .loading(rootURL: rootURL)
        navigationHistory.reset(to: nil)

        if rootURL.startAccessingSecurityScopedResource() {
            securityScopedURL = rootURL
        }

        scanTask = Task { [weak self] in
            do {
                let nodes: [PDFTreeNode]
                if let validInitialPDF,
                   validInitialPDF.deletingLastPathComponent()
                    != rootURL {
                    nodes = try await PDFDirectoryScanner.scan(
                        directory: rootURL,
                        revealing: validInitialPDF
                    )
                } else {
                    nodes = try await PDFDirectoryScanner.scan(
                        directory: rootURL
                    )
                }

                self?.finishOpening(
                    rootURL: rootURL,
                    nodes: nodes,
                    initialPDF: validInitialPDF,
                    selectsFirstPDF: selectsFirstPDF,
                    generation: generation
                )
            } catch is CancellationError {
                return
            } catch {
                self?.failOpening(
                    rootURL: rootURL,
                    error: error,
                    generation: generation
                )
            }
        }
    }

    private func finishOpening(
        rootURL: URL,
        nodes: [PDFTreeNode],
        initialPDF: URL?,
        selectsFirstPDF: Bool,
        generation: UUID
    ) {
        guard workspaceGeneration == generation else {
            return
        }

        let selectedPDF = initialPDF
            ?? (selectsFirstPDF ? nodes.firstPDF : nil)
        state = .active(
            Workspace(
                rootURL: rootURL,
                nodes: nodes,
                selectedPDF: selectedPDF
            )
        )
        navigationHistory.reset(to: selectedPDF)
    }

    private func failOpening(
        rootURL: URL,
        error: Error,
        generation: UUID
    ) {
        guard workspaceGeneration == generation else {
            return
        }

        let message = error.localizedDescription
        state = .failed(
            rootURL: rootURL,
            message: message
        )
        presentedError = message
    }

    private func finishExpansion(
        directory: URL,
        children: [PDFTreeNode],
        generation: UUID
    ) {
        guard
            workspaceGeneration == generation,
            var workspace = activeWorkspace
        else {
            return
        }

        workspace.nodes =
            workspace.nodes.replacingDirectoryContents(
            at: directory,
            with: .loaded(children),
        )
        state = .active(workspace)
    }

    private func failExpansion(
        directory: URL,
        generation: UUID
    ) {
        guard
            workspaceGeneration == generation,
            var workspace = activeWorkspace
        else {
            return
        }

        workspace.nodes =
            workspace.nodes.replacingDirectoryContents(
            at: directory,
            with: .unavailable,
        )
        state = .active(workspace)
    }

    private func reveal(
        _ pdf: URL,
        in workspace: Workspace
    ) {
        let generation = workspaceGeneration
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let nodes = try await PDFDirectoryScanner.scan(
                    directory: workspace.rootURL,
                    revealing: pdf
                )
                guard
                    workspaceGeneration == generation,
                    var current = activeWorkspace,
                    current.rootURL == workspace.rootURL
                else {
                    return
                }

                current.nodes = nodes
                state = .active(current)
            } catch {
                return
            }
        }
    }

    private func stopAccessingWorkspace() {
        securityScopedURL?
            .stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    private func isPDF(
        _ pdf: URL,
        inside rootURL: URL
    ) -> Bool {
        pdf.pathExtension.caseInsensitiveCompare("pdf")
            == .orderedSame
            && isDescendant(pdf, of: rootURL)
    }

    private func isDescendant(
        _ url: URL,
        of rootURL: URL
    ) -> Bool {
        let rootComponents =
            rootURL.standardizedFileURL.pathComponents
        let components =
            url.standardizedFileURL.pathComponents

        return components.count > rootComponents.count
            && components.starts(with: rootComponents)
    }
}
