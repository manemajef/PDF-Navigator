import SwiftUI

/// Adapts workspace-scoped recent PDFs to the shared gallery.
struct RecentPDFGridView: View {
    let urls: [URL]
    let onOpenPDF: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void
    let onRevealInFinder: (URL) -> Void

    var body: some View {
        GalleryView(
            sections: [
                GallerySection(
                    id: .recents,
                    title: "Recents",
                    items: urls.map(GalleryItem.pdf),
                    collapsedRowCount: 2
                )
            ],
            emptySymbolName: "clock",
            emptyMessage: "No recent PDFs in this workspace",
            onOpenPDF: onOpenPDF,
            onOpenFolder: { _ in },
            onOpenPDFInNewTab: onOpenPDFInNewTab,
            onRevealInFinder: onRevealInFinder
        )
    }
}

#if DEBUG
#Preview("Recent PDFs") {
    RecentPDFGridView(
        urls: DevelopmentConfiguration.loadPDFs(limit: 12),
        onOpenPDF: { _ in },
        onOpenPDFInNewTab: { _ in },
        onRevealInFinder: { _ in }
    )
    .frame(width: 700, height: 620)
}
#endif
