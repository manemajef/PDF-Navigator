import SwiftUI

/// The workspace root presented as an ordinary folder Gallery.
struct LibraryView: View {
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let onOpenPDF: (URL) -> Void
    let onOpenFolder: (URL) -> Void
    var body: some View {
        ScrollView {
            LibraryGridView(
                folderURLs: folderURLs,
                pdfURLs: pdfURLs,
                emptyMessage: "No Content to show..",
                onOpenPDF: onOpenPDF,
                onOpenFolder: onOpenFolder
            )
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Root Library") {
    LibraryView(
        folderURLs: DevelopmentConfiguration.demoFolderURLs,
        pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
        onOpenPDF: { _ in },
        onOpenFolder: { _ in }
    )
    .frame(width: 700, height: 620)
}
#endif
