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
        }
    }
}
