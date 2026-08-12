import SwiftUI

/// One folder in a gallery, drawn as a contained mini-grid of its PDFs.
///
/// Draws only — it takes no actions, and owns no state beyond the previews it
/// loads for itself.
struct FolderCardView: View {
    private static let width: CGFloat = 100

    let url: URL
    let isSelected: Bool

    @State private var previewURLs: [URL] = []

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                folderSurface

                if previewURLs.isEmpty {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                } else if previewURLs.count == 1 {
                    ThumbnailView(
                        url: previewURLs[0],
                        size: CGSize(width: 68, height: 92),
                        cornerRadius: 5,
                        showsShadow: true
                    )
                } else {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(32), spacing: 4),
                            count: 2
                        ),
                        spacing: 4
                    ) {
                        ForEach(previewURLs, id: \.self) { pdfURL in
                            ThumbnailView(
                                url: pdfURL,
                                size: CGSize(width: 32, height: 38),
                                cornerRadius: 4,
                                showsShadow: true
                            )
                        }
                    }
                }
            }
            .frame(width: Self.width, height: Self.width)

            GalleryItemLabel(title: url.lastPathComponent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .gallerySelection(isSelected)
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
#Preview("Folder Card") {
    let shortFolderURL = DevelopmentConfiguration.demoFolderURLs.first
        ?? DevelopmentConfiguration.demoDirURL

    HStack(alignment: .top, spacing: 24) {
        FolderCardView(url: shortFolderURL, isSelected: false)
        FolderCardView(
            url: DevelopmentConfiguration.demoLongNameFolderURL,
            isSelected: true
        )
    }
    .frame(width: 340)
    .padding(32)
}
#endif
