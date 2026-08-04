import SwiftUI

struct WorkspaceToolbar: CustomizableToolbarContent {
    let session: TabSession
    let commands: WindowCommands

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "navigation", placement: .navigation) {
            ControlGroup {
                Button(action: session.goBack) {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(!session.canGoBack)

                Button(action: session.goForward) {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(!session.canGoForward)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(id: "previousPage", placement: .secondaryAction) {
            ControlGroup{
                Button(action: commands.goToPreviousPage) {
                    Label("Previous Page", systemImage: "chevron.up")
                }
                .disabled(!hasPDF)
                Button(action: commands.goToNextPage) {
                    Label("Next Page", systemImage: "chevron.down")
                }
                .disabled(!hasPDF)
            }.controlGroupStyle(.navigation)
     
        }
        .defaultCustomization(.hidden)

        ToolbarItem(id: "nextPage", placement: .secondaryAction) {
           
        }
        .defaultCustomization(.hidden)

        ToolbarItem(id: "zoomOut", placement: .secondaryAction) {
            Button(action: commands.zoomOut) {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .disabled(!hasPDF)
        }
        .defaultCustomization(.hidden)
        ToolbarItem(id: "actualSize", placement: .secondaryAction) {
            Button(action: commands.showActualSize) {
                Label("Actual Size", systemImage: "1.magnifyingglass")
            }.disabled(!hasPDF)
        }

        ToolbarItem(id: "zoomIn", placement: .secondaryAction) {
            Button(action: commands.zoomIn) {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .disabled(!hasPDF)
        }
        .defaultCustomization(.hidden)

        ToolbarItem(id: "pdfActionShare") {
            Button(action: commands.openCurrentPDFInDefaultApp) {
                Label("Open in Default App", systemImage: "arrow.up.forward.app")
            }
            .disabled(!hasPDF)
            
        }
        ToolbarItem(id: "pdfActionOpenDefaultApp") {
            Button(action: commands.openCurrentPDFInDefaultApp) {
                Label("Open in Default App", systemImage: "arrow.up.forward.app")
            }
            .disabled(!hasPDF)
            
        }
        

        ToolbarItem(id: "zoomPresets", placement: .primaryAction) {
            ControlGroup {
                

                Button(action: commands.zoomToFit) {
                    Label(
                        "Zoom to Fit",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                }
            }
            .disabled(!hasPDF)
        }

        ToolbarItem(id: "newTab", placement: .primaryAction) {
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

#if DEBUG
private struct WorkspaceToolbarPreviewHost: View {
    @State private var session = TabSession(
        request: .folder(DevelopmentConfiguration.demoDirURL)
    )

    var body: some View {
        Text("Workspace")
            .frame(width: 800, height: 500)
            .navigationTitle(session.windowTitle)
            .toolbar {
                WorkspaceToolbar(
                    session: session,
                    commands: .preview
                )
            }
    }
}

#Preview("Workspace - Home") {
    WorkspaceToolbarPreviewHost()
}
#endif
