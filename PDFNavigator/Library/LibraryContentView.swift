import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct LibraryContentView: View {
    let session: WorkspaceSession

    var body: some View {
        if case .library(let folderURL) = session.mode {
            let isRoot = folderURL == session.root
            let items = DirectoryScanner.items(in: folderURL)

            LibraryView(
                isRoot: isRoot,
                recentURLs: isRoot
                    ? RecentLocationsStore.shared.recentPDFs(in: session.root)
                    : [],
                folderURLs: items.filter(\.isDirectory).map(\.url),
                pdfURLs: items.filter { !$0.isDirectory }.map(\.url),
                onSelectPDF: session.select,
                onSelectFolder: session.showFolder
            )
        }
    }
}
