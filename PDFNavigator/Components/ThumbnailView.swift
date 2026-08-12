import AppKit
import SwiftUI

struct ThumbnailView: View {
    private struct LoadedThumbnail {
        let requestID: String
        let image: NSImage
    }

    @Environment(\.displayScale) private var displayScale
    @State private var loadedThumbnail: LoadedThumbnail?

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
            if let image = displayedImage {
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
        .task(id: requestID) {
            guard let image = await ThumbnailCache.shared.image(
                for: url,
                size: size,
                scale: displayScale
            ) else { return }
            loadedThumbnail = LoadedThumbnail(requestID: requestID, image: image)
        }
    }

    private var displayedImage: NSImage? {
        if loadedThumbnail?.requestID == requestID {
            return loadedThumbnail?.image
        }
        return ThumbnailCache.shared.cachedImage(
            for: url,
            size: size,
            scale: displayScale
        )
    }

    private var requestID: String {
        "\(url.path)|\(size.width)x\(size.height)@\(displayScale)"
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
