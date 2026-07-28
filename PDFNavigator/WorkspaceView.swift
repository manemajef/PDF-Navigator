import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @Environment(\.openWindow) private var openWindow

    @StateObject private var session: WorkspaceSession
    @StateObject private var window: WindowBridge
    @State private var reader = PDFReaderHandle()

    @State private var showingPicker = false
    @State private var presentedInitialPicker = false
    @State private var searchText = ""
    @State private var showingWelcome: Bool
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    private let presentsPicker: Bool
    private let lastSelectedPDF: URL?

    init(
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        lastSelectedPDF: URL? = nil,
        launchID: UUID? = nil,
        presentsPicker: Bool = false,
        startsAtWelcome: Bool = false
    ) {
        self.presentsPicker = presentsPicker
        self.lastSelectedPDF = lastSelectedPDF
        _session = StateObject(
            wrappedValue: WorkspaceSession(
                initialPDF: initialPDF,
                initialWorkspace: initialWorkspace,
                selectsInitialPDF: !startsAtWelcome
            )
        )
        _window = StateObject(wrappedValue: WindowBridge(launchID: launchID))
        _showingWelcome = State(initialValue: startsAtWelcome)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigatorView(
                session: session,
                onOpenPDFInNewTab: openPDFInNewTab
            )
            .navigationTitle(session.folderName)
            .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 350)
            .toolbar {
                if columnVisibility != .detailOnly && !window.isInTabGroup {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: actions.createTab) {
                            Label("New Tab", systemImage: "plus")
                        }
                        .help("New Tab")
                        .disabled(!actions.canCreateTab)
                    }
                }
            }
        } detail: {
            content
                .ignoresSafeArea(.container, edges: .top)
                .toolbarRole(.editor)
                .toolbar {
                    WorkspaceToolbar(actions: actions)
                }
                .searchable(
                    text: $searchText,
                    placement: .toolbar,
                    prompt: "Search Current PDF"
                )
        }
        .workspaceToolbarAppearance(isHidden: !window.isToolbarVisible)
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.folder, .pdf],
            allowsMultipleSelection: false
        ) { result in
            do {
                if let url = try result.get().first {
                    session.open(url)
                    showingWelcome = false
                }
            } catch {
                session.report(error)
            }
        }
        .alert(
            "Couldn’t Read Files",
            isPresented: errorPresentation,
            presenting: session.errorMessage
        ) { _ in
            Button("OK", action: session.dismissError)
        } message: {
            Text($0)
        }
        .background {
            WindowReader {
                window.resolve($0, onNewTab: createWorkspaceTab)
            }
        }
        .focusedSceneValue(\.workspaceActions, actions)
        .onChange(of: window.hasWindow, initial: true) {
            if $1 { presentInitialPicker() }
        }
        .onChange(of: session.selectedPDF) {
            if $1 != nil { showingWelcome = false }
        }
    }

    @ViewBuilder
    private var content: some View {
        if showingWelcome {
            WorkspaceWelcomeView(
                workspaceName: session.folderName,
                lastSelectedPDF: lastSelectedPDF,
                hasWorkspace: session.rootURL != nil,
                onOpenLastPDF: openLastPDF,
                onLoadNewWorkspace: { showingPicker = true }
            )
        } else if session.isLoading && session.items.isEmpty {
            ProgressView("Loading Workspace…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let pdf = session.selectedPDF {
            PDFReaderView(url: pdf, searchText: searchText, handle: reader)
                .navigationTitle(pdf.lastPathComponent)
        } else {
            WorkspaceEmptyView { showingPicker = true }
        }
    }

    private var actions: WorkspaceActions {
        WorkspaceActions(
            session: session,
            reader: reader,
            canCreateTab: window.hasWindow,
            createTab: createWorkspaceTab,
            duplicateTab: duplicateCurrentTab
        )
    }

    private var errorPresentation: Binding<Bool> {
        Binding {
            session.errorMessage != nil
        } set: {
            if !$0 { session.dismissError() }
        }
    }

    private func createWorkspaceTab() {
        openAsTab(
            .newTab(
                rootURL: session.rootURL,
                lastSelectedPDF: session.selectedPDF
            )
        )
    }

    private func duplicateCurrentTab() {
        if let pdf = session.selectedPDF {
            openPDFInNewTab(pdf)
        }
    }

    private func openPDFInNewTab(_ pdf: URL) {
        guard let rootURL = session.rootURL else { return }
        openAsTab(.duplicate(rootURL: rootURL, selectedPDF: pdf))
    }

    private func openAsTab(_ launch: WorkspaceLaunch) {
        guard window.registerAsTabSource(for: launch.id) else { return }
        openWindow(value: launch)
    }

    private func presentInitialPicker() {
        guard presentsPicker,
              session.rootURL == nil,
              !presentedInitialPicker else {
            return
        }
        presentedInitialPicker = true
        showingPicker = true
    }

    private func openLastPDF() {
        if let lastSelectedPDF {
            session.select(lastSelectedPDF)
        }
    }
}

#if DEBUG
#Preview("Demo PDF") {
    WorkspaceView(initialPDF: DevelopmentConfiguration.demoPDFURL)
}
#endif
