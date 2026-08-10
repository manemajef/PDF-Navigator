import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct LibraryContentView: View {
    let session: WorkspaceSession

    var body: some View {
        if case .library(let folderURL) = session.mode {
            let items = DirectoryScanner.items(in: folderURL)
            let folderURLs = items.filter(\.isDirectory).map(\.url)
            let pdfURLs = items.filter { !$0.isDirectory }.map(\.url)

            if folderURL == session.root {
                LibraryView(
                    folderURLs: folderURLs,
                    pdfURLs: pdfURLs,
                    onSelectPDF: session.select,
                    onSelectFolder: session.showFolder
                )
            } else {
                FolderGalleryView(
                    folderURLs: folderURLs,
                    pdfURLs: pdfURLs,
                    onSelectPDF: session.select,
                    onSelectFolder: session.showFolder
                )
            }
        }
    }
}
