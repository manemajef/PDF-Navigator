import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct LibraryContentView: View {
    let session: WorkspaceSession

    var body: some View {
        if case .library(let folderURL) = session.mode {
            let items = DirectoryScanner.items(in: folderURL)
            let folderURLs = items.filter(\.isDirectory).map(\.url)
            let pdfURLs = items.filter { !$0.isDirectory }.map(\.url)
            
            LibraryView(
                folderURLs: folderURLs,
                pdfURLs: pdfURLs,
                onOpenPDF: session.show,
                onOpenFolder: session.showFolder
            )
            // A different folder is a different library: this discards the
            // previous folder's selection instead of carrying it over.
            .id(folderURL)
        }
    }
}
