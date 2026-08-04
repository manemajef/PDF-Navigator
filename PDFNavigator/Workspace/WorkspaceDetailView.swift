import SwiftUI

struct WorkspaceDetailView: View {
    let session: TabSession
    let commands: WindowCommands
    let readerController: PDFReaderController

    var body: some View {
        switch session.mode {
        case .workspaceHome(let root):
            WorkspaceHomeContainerView(
                rootURL: root,
                onOpenDifferent: commands.chooseLocation,
                onSelectPDF: session.select
            )

        case .reading:
            if let pdfSession = session.pdfSession {
                PDFReaderView(
                    controller: readerController,
                    pdfSession: pdfSession
                )
            }
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
