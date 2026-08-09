import Foundation

struct OpenRequest: Equatable {
    let workspaceRootURL: URL
    let selectedPDFURL: URL?

    nonisolated static func folder(_ url: URL) -> Self {
        Self(
            workspaceRootURL: url.standardizedFileURL, selectedPDFURL: nil
        )
    }

    nonisolated static func pdf(_ url: URL) -> Self {
        let pdfURL = url.standardizedFileURL
        return pdf(pdfURL, in: pdfURL.deletingLastPathComponent())
    }

    nonisolated static func pdf(_ url: URL, in workspaceRootURL: URL) -> Self {
        Self(workspaceRootURL: workspaceRootURL, selectedPDFURL: url.standardizedFileURL)
    }
}
