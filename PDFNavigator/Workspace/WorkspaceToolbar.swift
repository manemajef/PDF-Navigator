import SwiftUI

struct WorkspaceToolbar: ToolbarContent {
    let canGoBack: Bool
    let canGoForward: Bool

    let onGoBack: () -> Void
    let onGoForward: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button(action: onGoBack) {
                    Label(
                        "Back",
                        systemImage: "chevron.backward"
                    )
                }
                .help("Back")
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!canGoBack)

                Button(action: onGoForward) {
                    Label(
                        "Forward",
                        systemImage: "chevron.forward"
                    )
                }
                .help("Forward")
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!canGoForward)
            }
            .controlGroupStyle(.navigation)
            .labelStyle(.iconOnly)
        }

        ToolbarSpacer(.fixed, placement: .navigation)
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
