import SwiftUI

struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceActions)
    private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Workspace Tab") {
                actions?.createWorkspaceTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(
                actions?.canCreateWorkspaceTab != true
            )

            Button("Duplicate Current Tab") {
                actions?.duplicateTab()
            }
            .disabled(actions?.canDuplicateTab != true)
        }

        CommandMenu("Navigate") {
            Button("Back") {
                actions?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(actions?.canGoBack != true)

            Button("Forward") {
                actions?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(actions?.canGoForward != true)

            Divider()

            Button("Previous PDF Page") {
                actions?.reader.goToPreviousPage()
            }
            .disabled(
                actions?.reader.capabilities
                    .canGoToPreviousPage != true
            )

            Button("Next PDF Page") {
                actions?.reader.goToNextPage()
            }
            .disabled(
                actions?.reader.capabilities
                    .canGoToNextPage != true
            )

            Button("Back in PDF") {
                actions?.reader.goBack()
            }
            .disabled(
                actions?.reader.capabilities.canGoBack
                    != true
            )

            Button("Forward in PDF") {
                actions?.reader.goForward()
            }
            .disabled(
                actions?.reader.capabilities.canGoForward
                    != true
            )
        }

        CommandMenu("PDF") {
            Button("Zoom In") {
                actions?.reader.zoomIn()
            }
            .disabled(
                actions?.reader.capabilities.canZoomIn
                    != true
            )

            Button("Zoom Out") {
                actions?.reader.zoomOut()
            }
            .disabled(
                actions?.reader.capabilities.canZoomOut
                    != true
            )

            Button("Actual Size") {
                actions?.reader.showActualSize()
            }
            .disabled(
                actions?.reader.capabilities.hasDocument
                    != true
            )

            Button("Zoom to Fit") {
                actions?.reader.zoomToFit()
            }
            .disabled(
                actions?.reader.capabilities.hasDocument
                    != true
            )
        }
    }
}
