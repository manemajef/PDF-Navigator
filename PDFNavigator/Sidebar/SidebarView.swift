import SwiftUI

struct SidebarView: View {
    let session: TabSession
    let presentation: WorkspacePresentation
    let commands: WindowCommands

    @State private var itemCount: Int?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                SidebarHeaderView(
                    title: workspaceName,
                    isSearchEnabled: session.pdfSession?.hasDocument == true
                ) {
                    presentation.isSearchPresented = true
                }
                .fixedSize(horizontal: false, vertical: true)

                NavigatorView(
                    rootURL: session.root,
                    selectedPDFURL: session.selection,
                    onSelectPDF: session.select,
                    onOpenInNewTab: commands.openInNewTab,
                    itemCount: $itemCount
                )
                .frame(minHeight: 0, maxHeight: .infinity)
                .layoutPriority(1)

                SidebarFooterView(itemCount: itemCount) {
                    commands.revealInFinder(session.root)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
//            .padding(.top, geometry.safeAreaInsets.top)
        }
    }

    private var workspaceName: String {
        session.root.lastPathComponent.isEmpty
            ? session.root.path
            : session.root.lastPathComponent
    }
}

#if DEBUG
#Preview("Sidebar") {
    SidebarView(
        session: TabSession(request: .pdf(DevelopmentConfiguration.demoPDFURL)),
        presentation: WorkspacePresentation(),
        commands: .preview
    )
    .frame(width: 240, height: 600)
}
#endif
