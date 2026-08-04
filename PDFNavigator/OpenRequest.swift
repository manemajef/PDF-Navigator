import Foundation

enum OpenRequest {
    case folder(URL)
    case pdf(URL)

    nonisolated var workspaceRootURL: URL {
        switch self {
        case .folder(let url):
            url.standardizedFileURL
        case .pdf(let url):
            url.standardizedFileURL.deletingLastPathComponent()
        }
    }

    nonisolated var selectedPDFURL: URL? {
        switch self {
        case .folder:
            nil
        case .pdf(let url):
            url.standardizedFileURL
        }
    }
}
