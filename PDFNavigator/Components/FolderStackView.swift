import SwiftUI

struct FolderStackView: View {
    private static let thumbnailSize = CGSize(width: 120, height: 168)
    private static let placements = [
        StackPlacement(scale: 0.92, rotation: 0, offset: CGSize(width: -2, height: 4)),
        StackPlacement(scale: 0.88, rotation: 4.5, offset: CGSize(width: 6, height: -4)),
        StackPlacement(scale: 0.84, rotation: -4, offset: CGSize(width: -6, height: -6)),
    ]

    private struct StackPlacement {
        let scale: CGFloat
        let rotation: Double
        let offset: CGSize
    }

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
                ZStack(alignment: .bottomTrailing) {
                    if previewURLs.isEmpty {
                        emptyThumbnail
                    } else {
                        ForEach(Array(previewURLs.prefix(3).enumerated()), id: \.element) {
                            index, pdfURL in
                            let placement = Self.placements[index]

                            ThumbnailView(
                                url: pdfURL,
                                size: CGSize(
                                    width: Self.thumbnailSize.width * placement.scale,
                                    height: Self.thumbnailSize.height * placement.scale
                                ),
                                cornerRadius: 6,
                                showsShadow: true
                            )
                            .rotationEffect(.degrees(placement.rotation))
                            .offset(x: placement.offset.width, y: placement.offset.height)
                        }
                    }

                    folderBadge
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .frame(
                    width: Self.thumbnailSize.width,
                    height: Self.thumbnailSize.height
                )

                GalleryItemLabel(title: url.lastPathComponent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .task(id: url) {
            previewURLs = DirectoryScanner.previewPDFs(in: url, limit: 3)
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

    @ViewBuilder
    private var folderBadge: some View {
        if #available(macOS 26.0, *) {
            folderBadgeLabel
                .glassEffect( in: Circle())
        } else {
            folderBadgeLabel
                .background(.regularMaterial, in: Circle())
        }
    }

    private var folderBadgeLabel: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: 28, ))
            .foregroundStyle(.blue)
            .frame(width: 52, height: 52)
    }
}


#if DEBUG
#Preview("Folder Stack Names") {
    let shortFolderURL = DevelopmentConfiguration.demoFolderURLs.first
        ?? DevelopmentConfiguration.demoDirURL

    HStack(alignment: .top, spacing: 24) {
        FolderStackView(
            url: shortFolderURL,
            isSelected: false,
            onSelect: {},
            onOpen: {}
        )
        FolderStackView(
            url: DevelopmentConfiguration.demoLongNameFolderURL,
            isSelected: true,
            onSelect: {},
            onOpen: {}
        )
    }
    .padding()
}
#endif
