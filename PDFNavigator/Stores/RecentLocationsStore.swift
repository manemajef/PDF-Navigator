import AppKit
import Foundation

@MainActor
final class RecentLocationsStore {
    static let shared = RecentLocationsStore()

    private let defaults = UserDefaults.standard
    private let recentWorkspacesKey = "recentWorkspaceURLs"
    private let recentPDFsKey = "recentPDFURLs"
    private let limit = 10

    private init() {}

    var recentWorkspaces: [URL] {
        Array(urls(forKey: recentWorkspacesKey).prefix(limit))
    }

    var recentPDFs: [URL] {
        Array(urls(forKey: recentPDFsKey).prefix(limit))
    }

    func noteWorkspace(_ url: URL) {
        note(url.standardizedFileURL, forKey: recentWorkspacesKey)
    }

    func notePDF(_ url: URL) {
        let url = url.standardizedFileURL
        guard url.pathExtension.lowercased() == "pdf" else { return }
        note(url, forKey: recentPDFsKey)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func clearWorkspaces() {
        defaults.removeObject(forKey: recentWorkspacesKey)
    }

    func clearPDFs() {
        defaults.removeObject(forKey: recentPDFsKey)
        NSDocumentController.shared.clearRecentDocuments(nil)
    }

    private func note(_ url: URL, forKey key: String) {
        var urls = urls(forKey: key)
        urls.removeAll { $0 == url }
        urls.insert(url, at: 0)
        if urls.count > limit {
            urls.removeLast(urls.count - limit)
        }
        defaults.set(urls.map(\.absoluteString), forKey: key)
    }

    private func urls(forKey key: String) -> [URL] {
        defaults.stringArray(forKey: key)?.compactMap(URL.init(string:)) ?? []
    }
    
    func recentPDFs(
        in workspaceRoot: URL,
        limit: Int = 12
    ) -> [URL] {
        guard limit > 0 else { return [] }

        return recentPDFs.lazy
            .map(\.standardizedFileURL)
            .filter { url in
                url.isDescendantOrSame(of: workspaceRoot)
                && FileManager.default.fileExists(atPath: url.path)
            }
            .prefix(limit)
            .map { $0 }
    }
}
