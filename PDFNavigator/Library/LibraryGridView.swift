import SwiftUI

struct LibraryGridView: View {
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let emptyMessage: String
    let onOpenPDF: (URL) -> Void
    let onOpenFolder: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void
    let onRevealInFinder: (URL) -> Void

    var body: some View {
        GalleryView(
            sections: [
                GallerySection(
                    id: .folders,
                    title: "Folders",
                    items: folderURLs.map(GalleryItem.folder)
                ),
                GallerySection(
                    id: .pdfs,
                    title: "PDFs",
                    items: pdfURLs.map(GalleryItem.pdf)
                ),
            ],
            emptySymbolName: "doc.text.magnifyingglass",
            emptyMessage: emptyMessage,
            onOpenPDF: onOpenPDF,
            onOpenFolder: onOpenFolder,
            onOpenPDFInNewTab: onOpenPDFInNewTab,
            onRevealInFinder: onRevealInFinder
        )
    }
}

#if DEBUG
#Preview("Library") {
    LibraryGridView(
        folderURLs: DevelopmentConfiguration.demoFolderURLs,
        pdfURLs: DevelopmentConfiguration.loadPDFs(limit: 20),
        emptyMessage: "This workspace has no PDFs yet",
        onOpenPDF: { _ in },
        onOpenFolder: { _ in },
        onOpenPDFInNewTab: { _ in },
        onRevealInFinder: { _ in }
    )
    .frame(width: 800, height: 650)
}
#endif
