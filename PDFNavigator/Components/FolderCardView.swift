import SwiftUI

/// The contained mini-grid treatment for a folder.
struct FolderCardView: View {
    private static let width: CGFloat = 120

    let url: URL
    let action: () -> Void

    @State private var previewURLs: [URL] = []

    var body: some View {
        GalleryItemButton(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    folderSurface

                    if previewURLs.isEmpty {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 38))
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
                                repeating: GridItem(.fixed(43), spacing: 8),
                                count: 2
                            ),
                            spacing: 8
                        ) {
                            ForEach(previewURLs, id: \.self) { pdfURL in
                                ThumbnailView(
                                    url: pdfURL,
                                    size: CGSize(width: 43, height: 50),
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .task(id: url) {
            previewURLs = folderPreviewPDFs(in: url, limit: 4)
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
        VStack(spacing: 24) {
            FolderCardView(url: shortFolderURL, action: {})
            FolderCardView(
                url: DevelopmentConfiguration.demoLongNameFolderURL,
                action: {}
            )
            Text("Contained grid")
                .foregroundStyle(.secondary)
        }
        VStack(spacing: 24) {
            FolderStackView(url: shortFolderURL, action: {})
            FolderStackView(
                url: DevelopmentConfiguration.demoLongNameFolderURL,
                action: {}
            )
            Text("Loose stack")
                .foregroundStyle(.secondary)
        }
    }
    .padding(32)
}
#endif
