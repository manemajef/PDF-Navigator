import AppKit
import Combine

@MainActor
final class RecentDocuments: ObservableObject {
    static let shared = RecentDocuments()

    @Published private(set) var urls: [URL]

    private let controller = NSDocumentController.shared

    private init() {
        urls = controller.recentDocumentURLs
    }

    func note(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }

        controller.noteNewRecentDocumentURL(url.standardizedFileURL)
        urls = controller.recentDocumentURLs
    }

    func clear() {
        controller.clearRecentDocuments(nil)
        urls = controller.recentDocumentURLs
    }
}
