import SwiftUI

/// The contained mini-grid treatment for a folder.
struct FolderCardView: View {
    private static let width: CGFloat = 120

    let url: URL
    let action: () -> Void

    @State private var previewURLs: [URL] = []

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )

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
                                    size: CGSize(width: 43, height: 57),
                                    cornerRadius: 4,
                                    showsShadow: true
                                )
                            }
                        }
                    }
                }
                .frame(width: Self.width, height: 138)

                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: Self.width, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .task(id: url) {
            previewURLs = folderPreviewPDFs(in: url, limit: 4)
        }
    }
}

#if DEBUG
#Preview("Folder Treatments") {
    let folderURL = DevelopmentConfiguration.demoFolderURLs.first
        ?? DevelopmentConfiguration.demoDirURL

    HStack(alignment: .top, spacing: 40) {
        VStack {
            FolderCardView(url: folderURL, action: {})
            Text("Contained grid")
                .foregroundStyle(.secondary)
        }
        VStack {
            FolderStackView(url: folderURL, action: {})
            Text("Loose stack")
                .foregroundStyle(.secondary)
        }
    }
    .padding(32)
}
#endif
