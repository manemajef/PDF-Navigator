import SwiftUI

struct WorkspaceToolbar: ToolbarContent {
    let actions: WorkspaceActions

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button(action: actions.session.goBack) {
                    Label("Back", systemImage: "chevron.backward")
                }
                .help("Back")
                .disabled(!actions.session.canGoBack)

                Button(action: actions.session.goForward) {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .help("Forward")
                .disabled(!actions.session.canGoForward)
            }
            .controlGroupStyle(.navigation)
            .labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .automatic){
            Button(action: actions.createTab){
                Label("New Tab",systemImage: "plus.rectangle.on.rectangle")
            }
        }
    }
}

private struct WorkspaceToolbarAppearance: ViewModifier {
    let isHidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.scrollEdgeEffectStyle(isHidden ? .soft : nil, for: .top)
        } else {
            content
        }
    }
}

extension View {
    func workspaceToolbarAppearance(isHidden: Bool) -> some View {
        modifier(WorkspaceToolbarAppearance(isHidden: isHidden))
    }
}
