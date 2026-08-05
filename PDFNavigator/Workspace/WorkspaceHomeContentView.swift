import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct WorkspaceHomeContentView: View {
    let session: TabSession
    let actions: WorkspaceActions

    var body: some View {
        if case .workspaceHome(let root) = session.mode {
            WorkspaceHomeContainerView(
                rootURL: root,
                onOpenDifferent: actions.chooseLocation,
                onSelectPDF: session.select
            )
        }
    }
}

private struct WorkspaceHomeContainerView: View {
    let rootURL: URL
    let onOpenDifferent: () -> Void
    let onSelectPDF: (URL) -> Void

    @State private var pdfURLs: [URL] = []

    var body: some View {
        WorkspaceHomeView(
            folderURL: rootURL,
            pdfURLs: pdfURLs,
            onOpenDifferent: onOpenDifferent,
            onSelectPDF: onSelectPDF
        )
        .task(id: rootURL) {
            pdfURLs = []
            let items = (try? await DirectoryScanner.items(in: rootURL)) ?? []
            guard !Task.isCancelled else { return }
            pdfURLs = items.filter { !$0.isDirectory }.map(\.url)
        }
    }
}
