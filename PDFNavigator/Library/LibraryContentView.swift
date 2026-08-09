import SwiftUI

/// SwiftUI content hosted in the AppKit workspace detail pane.
struct LibraryContentView: View {
    let session: WorkspaceSession
    let actions: ShellActions

    var body: some View {
        if case .library(let root) = session.mode {
            LibraryContainerView(
                rootURL: root,
                onOpenDifferent: actions.chooseLocation,
                onSelectPDF: session.select
            )
        }
    }
}

private struct LibraryContainerView: View {
    let rootURL: URL
    let onOpenDifferent: () -> Void
    let onSelectPDF: (URL) -> Void

    var body: some View {
        LibraryView(
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
