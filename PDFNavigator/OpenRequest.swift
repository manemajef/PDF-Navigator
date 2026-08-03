import Foundation

enum OpenRequest {
    case empty
    case folder(URL)
    case pdf(URL)

    nonisolated var workspaceRootURL: URL? {
        switch self {
        case .empty:
            nil
        case .folder(let url):
            url.standardizedFileURL
        case .pdf(let url):
            url.standardizedFileURL.deletingLastPathComponent()
        }
    }

    nonisolated var selectedPDFURL: URL? {
        switch self {
        case .empty, .folder:
            nil
        case .pdf(let url):
            url.standardizedFileURL
        }
    }
}
