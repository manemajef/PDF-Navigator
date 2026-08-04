import AppKit
import SwiftUI

final class WorkspaceHomeController: NSViewController {
    private let actions: WindowActions
    private var workspaceRootURL: URL?
    private var pdfURLs: [URL] = []
    private var hostingController: NSHostingController<WorkspaceHomeView>?

    init(actions: WindowActions) {
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func loadView() {
        let container = NSView()
        view = container
        updateView()
    }

    func display(workspaceRootURL: URL) {
        self.workspaceRootURL = workspaceRootURL
        scanWorkspacePDFs(root: workspaceRootURL)
    }

    private func scanWorkspacePDFs(root: URL) {
        Task { [weak self] in
            let items = (try? await DirectoryScanner.items(in: root)) ?? []
            let pdfs = items.filter { !$0.isDirectory && $0.url.pathExtension.lowercased() == "pdf" }
                .map { $0.url }
            await MainActor.run {
                self?.pdfURLs = pdfs
                self?.updateView()
            }
        }
    }

    private func updateView() {
        guard let workspaceRootURL else { return }
        loadViewIfNeeded()

        let homeView = WorkspaceHomeView(
            folderURL: workspaceRootURL,
            pdfURLs: pdfURLs,
            onOpenDifferent: { [weak self] in
                self?.actions.chooseLocation()
            },
            onSelectPDF: { [weak self] url in
                self?.actions.openPDF(url)
            }
        )

        if let hostingController {
            hostingController.rootView = homeView
        } else {
            let hosting = NSHostingController(rootView: homeView)
            addChild(hosting)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            self.hostingController = hosting
        }
    }
}
