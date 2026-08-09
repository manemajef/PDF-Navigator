import AppKit
import QuickLookThumbnailing
import SwiftUI

// MARK: - Shared Thumbnail Cache

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    func image(for url: URL, targetSize: CGSize) -> NSImage? {
        let key = cacheKey(url: url, size: targetSize)
        return cache.object(forKey: key)
    }

    func set(image: NSImage, for url: URL, targetSize: CGSize) {
        let key = cacheKey(url: url, size: targetSize)
        cache.setObject(image, forKey: key)
    }

    private func cacheKey(url: URL, size: CGSize) -> NSURL {
        let keyString = "\(url.standardizedFileURL.absoluteString)?w=\(Int(size.width))&h=\(Int(size.height))"
        return NSURL(string: keyString) ?? (url.standardizedFileURL as NSURL)
    }
}

// MARK: - Shared Thumbnail View

/// A reusable SwiftUI view that asynchronously renders a QuickLook thumbnail for any file or PDF URL
/// with automatic in-memory caching, fallback icon support, and custom styling.
struct ThumbnailView: View {
    @Environment(\.displayScale) private var displayScale

    let url: URL
    let size: CGSize
    let cornerRadius: CGFloat
    let showShadow: Bool
    let showBorder: Bool

    @State private var image: NSImage?

    init(
        url: URL,
        size: CGSize = CGSize(width: 120, height: 168),
        cornerRadius: CGFloat = 4,
        showShadow: Bool = false,
        showBorder: Bool = false
    ) {
        self.url = url.standardizedFileURL
        self.size = size
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
        self.showBorder = showBorder
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
        .overlay(
            Group {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                }
            }
        )
        .shadow(
            color: showShadow ? Color.black.opacity(0.18) : .clear,
            radius: showShadow ? 4 : 0,
            x: 0,
            y: showShadow ? 2 : 0
        )
        .task(id: "\(url.path)_\(Int(size.width))x\(Int(size.height))") {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        // Check cache first
        if let cached = ThumbnailCache.shared.image(for: url, targetSize: size) {
            self.image = cached
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: displayScale,
            representationTypes: .thumbnail
        )
        request.iconMode = true

        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request),
              !Task.isCancelled
        else {
            return
        }

        let resultImage = representation.nsImage
        ThumbnailCache.shared.set(image: resultImage, for: url, targetSize: size)
        self.image = resultImage
    }
}

// MARK: - Compatibility Typealias

typealias PDFThumbnailView = ThumbnailView

// MARK: - Previews

#if DEBUG
#Preview("Thumbnail View Variations") {
    HStack(alignment: .bottom, spacing: 20) {
        ThumbnailView(
            url: DevelopmentConfiguration.demoPDFURL,
            size: CGSize(width: 60, height: 84),
            cornerRadius: 4,
            showShadow: true
        )

        ThumbnailView(
            url: DevelopmentConfiguration.demoPDFURL,
            size: CGSize(width: 100, height: 140),
            cornerRadius: 6,
            showShadow: true,
            showBorder: true
        )

        ThumbnailView(
            url: DevelopmentConfiguration.demoPDFURL,
            size: CGSize(width: 140, height: 196),
            cornerRadius: 8,
            showShadow: true
        )
    }
    .padding(30)
}
#endif
