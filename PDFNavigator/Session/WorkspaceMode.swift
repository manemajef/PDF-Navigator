import Foundation

/// The single location coordinate for a workspace session.
nonisolated enum WorkspaceMode: Equatable {
    case startPage
    case library(URL)
    case reading(URL)

    var selectedPDFURL: URL? {
        guard case .reading(let url) = self else { return nil }
        return url
    }
}
