import AppKit
import SwiftUI

struct WorkspaceCommandActions {
    let canCreateWorkspaceTab: Bool
    let canDuplicateTab: Bool
    let isToolbarVisible: Bool
    let createWorkspaceTab: () -> Void
    let duplicateTab: () -> Void
}

private struct WorkspaceCommandActionsKey: FocusedValueKey {
    typealias Value = WorkspaceCommandActions
}

extension FocusedValues {
    var workspaceCommandActions: WorkspaceCommandActions? {
        get { self[WorkspaceCommandActionsKey.self] }
        set { self[WorkspaceCommandActionsKey.self] = newValue }
    }
}

struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceCommandActions)
    private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workspace Tab") {
                actions?.createWorkspaceTab()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(
                actions?.canCreateWorkspaceTab != true
            )

            Button("Duplicate Current Tab") {
                actions?.duplicateTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(actions?.canDuplicateTab != true)
        }

        CommandGroup(replacing: .toolbar) {
            Button(
                actions?.isToolbarVisible == false
                    ? "Show Toolbar"
                    : "Hide Toolbar"
            ) {
                guard let toolbar = (
                    NSApp.keyWindow ?? NSApp.mainWindow
                )?.toolbar else {
                    return
                }

                toolbar.isVisible.toggle()
            }
            .keyboardShortcut(
                "t",
                modifiers: [.command, .option]
            )
        }
    }
}
