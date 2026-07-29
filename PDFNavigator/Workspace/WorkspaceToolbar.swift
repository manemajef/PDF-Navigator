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
        if !actions.hasMultipleTabs {
            ToolbarItem(placement: .automatic){
                Button(action: actions.createTab){
                    Label("New Tab",systemImage: "plus.rectangle.on.rectangle")
                }
            }
        }
        
    }
}
