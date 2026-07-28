import Combine
import Foundation

@MainActor
final class WorkspaceSession: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var selectedPDF: URL?
    @Published private(set) var itemsByDirectory: [URL: [NavigatorItem]] = [:]
    @Published private(set) var loadingDirectories: Set<URL> = []
    @Published private(set) var errorMessage: String?

    private var history = NavigationHistory()
    private var scans: [URL: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var securityScopedURL: URL?

    init(
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        selectsInitialPDF: Bool = true
    ) {
        if let initialWorkspace {
            open(
                folder: initialWorkspace,
                selecting: selectsInitialPDF ? initialPDF : nil,
                selectsFirstPDF: selectsInitialPDF
            )
        } else if let initialPDF {
            open(pdf: initialPDF)
        }
    }

    deinit {
        scans.values.forEach { $0.cancel() }
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    var items: [NavigatorItem] {
        guard let rootURL else { return [] }
        return itemsByDirectory[rootURL] ?? []
    }

    var folderName: String {
        guard let rootURL else { return "PDFs" }
        return rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent
    }

    var isLoading: Bool {
        guard let rootURL else { return false }
        return loadingDirectories.contains(rootURL)
    }

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }

    func items(in directory: URL) -> [NavigatorItem]? {
        itemsByDirectory[directory.standardizedFileURL]
    }

    func isLoading(_ directory: URL) -> Bool {
        loadingDirectories.contains(directory.standardizedFileURL)
    }

    func open(_ url: URL) {
        if url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
            open(pdf: url)
        } else {
            open(folder: url)
        }
    }

    func open(pdf: URL) {
        let pdf = pdf.standardizedFileURL
        open(
            folder: pdf.deletingLastPathComponent(),
            selecting: pdf,
            selectsFirstPDF: true
        )
    }

    func open(folder: URL) {
        open(folder: folder, selecting: nil, selectsFirstPDF: true)
    }

    func select(_ pdf: URL) {
        guard let rootURL, isPDF(pdf, inside: rootURL) else { return }
        let pdf = pdf.standardizedFileURL
        history.visit(pdf)
        selectedPDF = pdf
    }

    func expand(_ directory: URL) {
        let directory = directory.standardizedFileURL
        guard let rootURL,
              isDescendant(directory, of: rootURL),
              itemsByDirectory[directory] == nil,
              !loadingDirectories.contains(directory) else {
            return
        }

        loadingDirectories.insert(directory)
        let currentGeneration = generation

        scans[directory] = Task { [weak self] in
            do {
                let items = try await DirectoryScanner.items(in: directory)
                guard let self, generation == currentGeneration else { return }
                itemsByDirectory[directory] = items
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = error.localizedDescription
            }

            self?.loadingDirectories.remove(directory)
            self?.scans[directory] = nil
        }
    }

    func goBack() {
        if let pdf = history.goBack() {
            selectedPDF = pdf
        }
    }

    func goForward() {
        if let pdf = history.goForward() {
            selectedPDF = pdf
        }
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func dismissError() {
        errorMessage = nil
    }

    private func open(
        folder: URL,
        selecting requestedPDF: URL?,
        selectsFirstPDF: Bool
    ) {
        scans.values.forEach { $0.cancel() }
        scans.removeAll()
        stopAccessingWorkspace()

        let root = folder.standardizedFileURL
        let selectedPDF = requestedPDF?.standardizedFileURL
        let validPDF = selectedPDF.flatMap { isPDF($0, inside: root) ? $0 : nil }
        let currentGeneration = UUID()

        generation = currentGeneration
        rootURL = root
        self.selectedPDF = nil
        itemsByDirectory = [:]
        loadingDirectories = [root]
        errorMessage = nil
        history.reset(to: nil)

        if root.startAccessingSecurityScopedResource() {
            securityScopedURL = root
        }

        scans[root] = Task { [weak self] in
            do {
                let directories = try await DirectoryScanner.items(
                    from: root,
                    revealing: validPDF
                )
                guard let self, generation == currentGeneration else { return }

                itemsByDirectory = directories
                let selection = validPDF ?? (
                    selectsFirstPDF
                        ? directories[root]?.first { !$0.isDirectory }?.url
                        : nil
                )
                self.selectedPDF = selection
                history.reset(to: selection)
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = error.localizedDescription
            }

            self?.loadingDirectories.remove(root)
            self?.scans[root] = nil
        }
    }

    private func stopAccessingWorkspace() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    private func isPDF(_ url: URL, inside root: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame
            && isDescendant(url.standardizedFileURL, of: root)
    }

    private func isDescendant(_ url: URL, of root: URL) -> Bool {
        let rootParts = root.standardizedFileURL.pathComponents
        let parts = url.standardizedFileURL.pathComponents
        return parts.count > rootParts.count && parts.starts(with: rootParts)
    }
}
