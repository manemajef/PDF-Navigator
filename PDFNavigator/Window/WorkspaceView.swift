import SwiftUI

struct WorkspaceView: View {
    let session: TabSession
    let presentation: WorkspacePresentation
    let commands: WindowCommands
    let readerController: PDFReaderController

    var body: some View {
        @Bindable var presentation = presentation

        NavigationSplitView(columnVisibility: $presentation.columnVisibility) {
            SidebarView(
                session: session,
                presentation: presentation,
                commands: commands
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 360)
        } detail: {
            WorkspaceDetailView(
                session: session,
                commands: commands,
                readerController: readerController
            )
        }
        .toolbar {
            WorkspaceToolbar(session: session, commands: commands)
        }
        .searchable(
            text: searchQuery,
            isPresented: $presentation.isSearchPresented,
            placement: .toolbar,
            prompt: "Search Current PDF"
        )
        .onSubmit(of: .search) {
            session.pdfSession?.selectNextMatch()
        }
    }

    private var searchQuery: Binding<String> {
        Binding(
            get: { session.pdfSession?.searchQuery ?? "" },
            set: { session.pdfSession?.search($0) }
        )
    }
}

#if DEBUG
#Preview("Workspace — Home") {
    WorkspaceView(
        session: TabSession(request: .folder(DevelopmentConfiguration.demoDirURL)),
        presentation: WorkspacePresentation(),
        commands: .preview,
        readerController: PDFReaderController()
    )
    .frame(width: 900, height: 650)
}

#Preview("Workspace — Reader") {
    WorkspaceView(
        session: TabSession(request: .pdf(DevelopmentConfiguration.demoPDFURL)),
        presentation: WorkspacePresentation(),
        commands: .preview,
        readerController: PDFReaderController()
    )
    .frame(width: 900, height: 650)
}
#endif
