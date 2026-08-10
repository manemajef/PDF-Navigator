import SwiftUI

struct FolderStackView: View {
    private static let thumbnailSize = CGSize(width: 120, height: 168)

    let url: URL
    let action: () -> Void

    @State private var previewURLs: [URL] = []

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if previewURLs.isEmpty {
                        emptyThumbnail
                    } else {
                        ForEach(Array(previewURLs.prefix(3).enumerated()), id: \.element) {
                            index, pdfURL in
                            ThumbnailView(
                                url: pdfURL,
                                size: scaledThumbnailSize(for: index),
                                cornerRadius: 6,
                                showsShadow: true
                            )
                            .rotationEffect(.degrees(rotation(for: index)))
                            .offset(
                                x: offset(for: index).width,
                                y: offset(for: index).height
                            )
                        }
                    }

                    Image(systemName: "folder.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .frame(
                    width: Self.thumbnailSize.width,
                    height: Self.thumbnailSize.height
                )

                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: Self.thumbnailSize.width, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .task(id: url) {
            previewURLs = folderPreviewPDFs(in: url, limit: 3)
        }
    }

    private var emptyThumbnail: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "folder")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
            }
    }

    private func scaledThumbnailSize(for index: Int) -> CGSize {
        let scale = 0.92 - CGFloat(index) * 0.04
        return CGSize(
            width: Self.thumbnailSize.width * scale,
            height: Self.thumbnailSize.height * scale
        )
    }

    private func rotation(for index: Int) -> Double {
        [0, 4.5, -4][index]
    }

    private func offset(for index: Int) -> CGSize {
        [CGSize(width: -2, height: 4),
         CGSize(width: 6, height: -4),
         CGSize(width: -6, height: -6)][index]
    }
}

func folderPreviewPDFs(in folderURL: URL, limit: Int) -> [URL] {
    let items = DirectoryScanner.items(in: folderURL)
    var pdfs = items.filter { !$0.isDirectory }.map(\.url)

    for folder in items where folder.isDirectory && pdfs.count < limit {
        pdfs.append(contentsOf: DirectoryScanner.items(in: folder.url)
            .filter { !$0.isDirectory }
            .map(\.url)
            .prefix(limit - pdfs.count))
    }
    return Array(pdfs.prefix(limit))
}

#if DEBUG
#Preview("Folder Stack") {
    FolderStackView(
        url: DevelopmentConfiguration.demoFolderURLs.first
            ?? DevelopmentConfiguration.demoDirURL,
        action: {}
    )
    .padding()
}
#endif
