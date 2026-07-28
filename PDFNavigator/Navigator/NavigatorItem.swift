import Foundation

struct NavigatorItem: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool

    nonisolated var id: URL { url }
    nonisolated var name: String { url.lastPathComponent }
}
