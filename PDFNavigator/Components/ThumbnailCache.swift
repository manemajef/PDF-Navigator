import AppKit
import QuickLookThumbnailing

/// The one thumbnail cache shared by SwiftUI previews and gallery cells.
///
/// Quick Look may cache its rendering work internally, but asking it again is
/// still asynchronous. Keeping the finished `NSImage` here lets a reused view
/// paint immediately instead of briefly falling back to the file icon.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let images = NSCache<NSString, NSImage>()
    private var requests: [String: Task<NSImage?, Never>] = [:]

    private init() {
        images.countLimit = 500
    }

    func cachedImage(for url: URL, size: CGSize, scale: CGFloat) -> NSImage? {
        images.object(forKey: key(for: url, size: size, scale: scale) as NSString)
    }

    func image(for url: URL, size: CGSize, scale: CGFloat) async -> NSImage? {
        let key = key(for: url, size: size, scale: scale)
        if let image = images.object(forKey: key as NSString) {
            return image
        }
        if let request = requests[key] {
            return await request.value
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        request.iconMode = true

        let task = Task {
            try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
                .nsImage
        }
        requests[key] = task

        let image = await task.value
        requests[key] = nil
        if let image {
            images.setObject(image, forKey: key as NSString)
        }
        return image
    }

    private func key(for url: URL, size: CGSize, scale: CGFloat) -> String {
        "\(url.standardizedFileURL.path)|\(size.width)x\(size.height)@\(scale)"
    }
}
