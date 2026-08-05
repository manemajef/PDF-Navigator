import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct WorkspaceHomeContentView: View {
    let session: TabSession
    let actions: WorkspaceActions

    var body: some View {
        if case .workspaceHome(let root) = session.mode {
            WorkspaceHomeContainerView(
                rootURL: root,
                onOpenDifferent: actions.chooseLocation,
                onSelectPDF: session.select
            )
        }
    }
}

private struct WorkspaceHomeContainerView: View {
    let rootURL: URL
    let onOpenDifferent: () -> Void
    let onSelectPDF: (URL) -> Void

    var body: some View {
        WorkspaceHomeView(
            folderURL: rootURL,
            pdfURLs: RecentLocationsStore.shared.recentPDFs(
                in: rootURL,
                limit: 12
            ),
            onOpenDifferent: onOpenDifferent,
            onSelectPDF: onSelectPDF
        )
    }
}
