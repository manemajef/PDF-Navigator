import SwiftUI

/// The folders and PDFs at one workspace location.
///
/// The workspace root also shows recent PDFs; nested folders do not.
struct LibraryView: View {
    let isRoot: Bool
    let recentURLs: [URL]
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

    var body: some View {
        ScrollView {
            LibraryGridView(
                recentURLs: isRoot ? recentURLs : [],
                folderURLs: folderURLs,
                pdfURLs: pdfURLs,
                emptyMessage: isRoot
                    ? "This workspace has no PDFs yet"
                    : "No folders or PDFs here",
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
        isRoot: true,
        recentURLs: DevelopmentConfiguration.loadPDFs(limit: 12),
        folderURLs: DevelopmentConfiguration.demoFolderURLs,
        pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
        onSelectPDF: { _ in },
        onSelectFolder: { _ in }
    )
    .frame(width: 700, height: 620)
}

#Preview("Folder Library") {
    LibraryView(
        isRoot: false,
        recentURLs: [],
        folderURLs: DevelopmentConfiguration.demoFolderURLs,
        pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
        onSelectPDF: { _ in },
        onSelectFolder: { _ in }
    )
    .frame(width: 700, height: 620)
}
#endif
