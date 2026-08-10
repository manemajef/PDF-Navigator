import SwiftUI

/// The workspace root presented as an ordinary folder Gallery.
struct LibraryView: View {
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

    var body: some View {
        ScrollView {
            LibraryGridView(
                folderURLs: folderURLs,
                pdfURLs: pdfURLs,
                emptyMessage: "This workspace has no PDFs yet",
                onSelectPDF: onSelectPDF,
                onSelectFolder: onSelectFolder
            )
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A nested folder presented as a visual gallery, without root-only sections.
struct FolderGalleryView: View {
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

    var body: some View {
        ScrollView {
            LibraryGridView(
                folderURLs: folderURLs,
                pdfURLs: pdfURLs,
                emptyMessage: "No folders or PDFs here",
                onSelectPDF: onSelectPDF,
                onSelectFolder: onSelectFolder
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
        onSelectPDF: { _ in },
        onSelectFolder: { _ in }
    )
    .frame(width: 700, height: 620)
}

#Preview("Folder Gallery") {
    FolderGalleryView(
        folderURLs: DevelopmentConfiguration.demoFolderURLs,
        pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
        onSelectPDF: { _ in },
        onSelectFolder: { _ in }
    )
    .frame(width: 700, height: 620)
}
#endif
