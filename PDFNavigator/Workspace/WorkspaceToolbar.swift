import SwiftUI

struct WorkspaceToolbar: ToolbarContent {
    let actions: WorkspaceActions
    let showsPrimaryNewTabAction: Bool
    let showsTabActions: Bool

    var body: some ToolbarContent {
        if showsPrimaryNewTabAction {
            ToolbarItem(placement: .primaryAction) {
                Button(action: actions.createWorkspaceTab) {
                    Label("New Tab", systemImage: "plus")
                }
                .help("New Tab")
                .disabled(!actions.canCreateWorkspaceTab)
            }
        }

        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button(action: actions.goBack) {
                    Label(
                        "Back",
                        systemImage: "chevron.backward"
                    )
                }
                .help("Back")
                .disabled(!actions.canGoBack)

                Button(action: actions.goForward) {
                    Label(
                        "Forward",
                        systemImage: "chevron.forward"
                    )
                }
                .help("Forward")
                .disabled(!actions.canGoForward)
            }
            .controlGroupStyle(.navigation)
            .labelStyle(.iconOnly)
        }

        if showsTabActions {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: actions.createWorkspaceTab) {
                    Label(
                        "New Workspace Tab",
                        systemImage: "folder.badge.plus"
                    )
                }
                .help("New Workspace Tab")
                .disabled(!actions.canCreateWorkspaceTab)

                Button(action: actions.duplicateTab) {
                    Label(
                        "Duplicate Current Tab",
                        systemImage:
                            "plus.rectangle.on.rectangle"
                    )
                }
                .help("Duplicate Current Tab")
                .disabled(!actions.canDuplicateTab)
            }
        }
    }
}

private struct WorkspaceToolbarAppearanceModifier:
    ViewModifier {
    let isToolbarHidden: Bool

    func body(content: Content) -> some View {
        content.scrollEdgeEffectStyle(
            isToolbarHidden ? .soft : nil,
            for: .top
        )
    }
}

extension View {
    func workspaceToolbarAppearance(
        isToolbarHidden: Bool
    ) -> some View {
        modifier(
            WorkspaceToolbarAppearanceModifier(
                isToolbarHidden: isToolbarHidden
            )
        )
    }
}
