import SwiftUI

struct WorkspaceToolbar: ToolbarContent {
    let session: TabSession
    let commands: WindowCommands

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: session.goBack) {
                Label("Back", systemImage: "chevron.backward")
            }
            .disabled(!session.canGoBack)

            Button(action: session.goForward) {
                Label("Forward", systemImage: "chevron.forward")
            }
            .disabled(!session.canGoForward)
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            Button(action: commands.goToPreviousPage) {
                Label("Previous Page", systemImage: "chevron.up")
            }
            .disabled(!hasPDF)

            Button(action: commands.goToNextPage) {
                Label("Next Page", systemImage: "chevron.down")
            }
            .disabled(!hasPDF)

            Button(action: commands.zoomOut) {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .disabled(!hasPDF)

            Button(action: commands.zoomIn) {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .disabled(!hasPDF)

            Button(action: commands.openCurrentPDFInDefaultApp) {
                Label("Open in Default App", systemImage: "arrow.up.forward.app")
            }
            .disabled(!hasPDF)

            Button(action: commands.shareCurrentPDF) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(!hasPDF)
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button(action: commands.showActualSize) {
                    Label("Actual Size", systemImage: "1.magnifyingglass")
                }

                Button(action: commands.zoomToFit) {
                    Label(
                        "Zoom to Fit",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                }
            }
            .disabled(!hasPDF)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                commands.newTab(.foreground)
            } label: {
                Label("New Tab", systemImage: "plus.rectangle.on.rectangle")
            }
        }
    }

    private var hasPDF: Bool {
        session.pdfSession?.hasDocument == true
    }
}
