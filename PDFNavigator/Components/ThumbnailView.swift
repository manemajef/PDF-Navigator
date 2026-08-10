import AppKit
import QuickLookThumbnailing
import SwiftUI

struct ThumbnailView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var image: NSImage?

    let url: URL
    let size: CGSize
    let cornerRadius: CGFloat
    let showsShadow: Bool

    init(
        url: URL,
        size: CGSize = CGSize(width: 120, height: 168),
        cornerRadius: CGFloat = 4,
        showsShadow: Bool = false
    ) {
        self.url = url.standardizedFileURL
        self.size = size
        self.cornerRadius = cornerRadius
        self.showsShadow = showsShadow
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: showsShadow ? .black.opacity(0.18) : .clear,
            radius: 4,
            y: 2
        )
        .task(id: url) {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: displayScale,
                representationTypes: .thumbnail
            )
            request.iconMode = true
            image = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
                .nsImage
        }
    }
}

#if DEBUG
#Preview("Thumbnail") {
    ThumbnailView(
        url: DevelopmentConfiguration.demoPDFURL,
        showsShadow: true
    )
    .padding()
}
#endif
