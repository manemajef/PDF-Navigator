import Foundation

/// The normalized input for pointing a workspace session somewhere.
struct OpenRequest: Equatable {
    let workspaceRootURL: URL
    let mode: WorkspaceMode

    /// The PDF this request opens, if any.
    var selectedPDFURL: URL? { mode.selectedPDFURL }

    /// Opens the workspace-scoped page shown by a new tab.
    nonisolated static func startPage(in workspaceRootURL: URL) -> Self {
        Self(
            workspaceRootURL: workspaceRootURL.standardizedFileURL,
            mode: .startPage
        )
    }

    /// Opens a folder as its own workspace, showing that folder's contents.
    nonisolated static func folder(_ url: URL) -> Self {
        let folderURL = url.standardizedFileURL
        return folder(folderURL, in: folderURL)
    }

    /// Shows a folder inside an existing workspace, leaving the root alone.
    nonisolated static func folder(_ url: URL, in workspaceRootURL: URL) -> Self {
        Self(
            workspaceRootURL: workspaceRootURL.standardizedFileURL,
            mode: .library(url.standardizedFileURL)
        )
    }

    nonisolated static func pdf(_ url: URL) -> Self {
        let pdfURL = url.standardizedFileURL
        return pdf(pdfURL, in: pdfURL.deletingLastPathComponent())
    }

    nonisolated static func pdf(_ url: URL, in workspaceRootURL: URL) -> Self {
        Self(
            workspaceRootURL: workspaceRootURL.standardizedFileURL,
            mode: .reading(url.standardizedFileURL)
        )
    }
}
