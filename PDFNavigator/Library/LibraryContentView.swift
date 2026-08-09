import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct LibraryContentView: View {
    let session: WorkspaceSession
    let actions: WindowActions

    var body: some View {
        if case .library(let root) = session.mode {
            LibraryContainerView(
                rootURL: root,
                session: session,
                onOpenDifferent: actions.chooseLocation,
                onSelectPDF: session.select
            )
        }
    }
}

private struct LibraryContainerView: View {
    let rootURL: URL
    let session: WorkspaceSession
    let onOpenDifferent: () -> Void
    let onSelectPDF: (URL) -> Void

    var body: some View {
        let items = DirectoryScanner.items(in: rootURL)
        let folderURLs = items.filter(\.isDirectory).map(\.url)
        let libraryPDFs = items.filter { !$0.isDirectory }.map(\.url)

        LibraryView(
            folderURL: rootURL,
            folderURLs: folderURLs,
            pdfURLs: libraryPDFs,
            recentPDFURLs: RecentLocationsStore.shared.recentPDFs(
                in: rootURL,
                limit: 12
            ),
            onOpenDifferent: onOpenDifferent,
            onSelectPDF: onSelectPDF,
            onSelectFolder: { selectedFolderURL in
                session.open(.folder(selectedFolderURL))
            }
        )
    }
}
