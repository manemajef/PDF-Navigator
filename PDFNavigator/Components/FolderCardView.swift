import SwiftUI

/// The contained mini-grid treatment for a folder.
struct FolderCardView: View {
    private static let width: CGFloat = 100

    let url: URL
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var previewURLs: [URL] = []

    var body: some View {
            GalleryItemView(
                isSelected: isSelected,
                onSelect: onSelect,
                onOpen: onOpen
            ) {
                VStack(spacing: 8) {
                    // ... everything here stays exactly as it is ...
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .task(id: url) {
                previewURLs = DirectoryScanner.previewPDFs(in: url, limit: 4)
            }
        }

    @ViewBuilder
    private var folderSurface: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .glassEffect(in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
        }
    }
}

#if DEBUG
#Preview("Folder Treatments") {
    let shortFolderURL = DevelopmentConfiguration.demoFolderURLs.first
        ?? DevelopmentConfiguration.demoDirURL

    HStack(alignment: .top, spacing: 40) {
        FolderCardView(url: shortFolderURL, isSelected: false, onSelect: {}, onOpen: {})
        FolderCardView(url: DevelopmentConfiguration.demoLongNameFolderURL, isSelected: true, onSelect: {}, onOpen: {})
//        FolderStackView(url: shortFolderURL, isSelected: false, onSelect: {}, onOpen: {})
//        FolderStackView(url: DevelopmentConfiguration.demoLongNameFolderURL, isSelected: false, onSelect: {}, onOpen: {})

    }
    .padding(32)
}
#endif
