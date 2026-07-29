import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @Environment(\.openWindow) private var openWindow

    @Binding private var restoration: WorkspaceLaunch?
    @StateObject private var session: WorkspaceSession
    @StateObject private var window: WindowBridge
    @ObservedObject private var recentDocuments = RecentDocuments.shared
    @State private var reader = PDFReaderHandle()

    @SceneStorage("workspaceSidebarVisible") private var isSidebarVisible = false
    @State private var restorationID: UUID
    @State private var showingPicker = false
    @State private var presentedInitialPicker = false
    @State private var searchText = ""
    @State private var showingWelcome: Bool

    private let presentsPicker: Bool
    private let lastSelectedPDF: URL?

    init(
        restoration: Binding<WorkspaceLaunch?> = .constant(nil),
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        lastSelectedPDF: URL? = nil,
        launchID: UUID? = nil,
        presentsPicker: Bool = false,
        startsAtWelcome: Bool = false
    ) {
        _restoration = restoration
        self.presentsPicker = presentsPicker
        self.lastSelectedPDF = lastSelectedPDF
        _restorationID = State(
            initialValue: restoration.wrappedValue?.id ?? UUID()
        )
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
        NavigationSplitView(columnVisibility: columnVisibility) {
            NavigatorView(
                session: session,
                onSelectPDF: selectPDF,
                onOpenPDFInNewTab: openPDFInNewTab
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 350)
           
        } detail: {
            content
                .navigationTitle(
                    session.selectedPDF?.lastPathComponent ?? session.folderName
                )
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
                .onSubmit(of: .search) {
                    reader.selectSearchMatch(
                        backward: NSEvent.modifierFlags.contains(.shift)
                    )
                }
        }
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.folder, .pdf],
            allowsMultipleSelection: false
        ) { result in
            do {
                if let url = try result.get().first {
                    open(url)
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
        .onOpenURL {
            open($0)
        }
        .onChange(of: window.hasWindow, initial: true) {
            if $1 {
                window.represent(session.selectedPDF)
                saveRestorationState()
                presentInitialPicker()
            }
        }
        .onChange(of: session.rootURL) {
            saveRestorationState()
        }
        .onChange(of: session.selectedPDF) {
            window.represent($1)
            if $1 != nil {
                showingWelcome = false
            }
            saveRestorationState()
        }
        .onChange(of: showingWelcome) {
            saveRestorationState()
        }
    }

    @ViewBuilder
    private var content: some View {
        if showingWelcome {
            WorkspaceWelcomeView(
                workspaceName: session.folderName,
                hasWorkspace: session.rootURL != nil,
                recentPDFs: Array(recentDocuments.urls.prefix(5)),
                workspaceRecentPDFs: workspaceRecentPDFs,
                onOpenRecentPDF: openRecentPDF,
                onLoadNewWorkspace: { showingPicker = true }
            )
        } else if session.isLoading && session.items.isEmpty {
            ProgressView("Loading Workspace…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let pdf = session.selectedPDF {
            PDFReaderView(url: pdf, searchText: searchText, handle: reader)
        } else {
            WorkspaceEmptyView { showingPicker = true }
        }
    }

    private var actions: WorkspaceActions {
        WorkspaceActions(
            session: session,
            reader: reader,
            canCreateTab: window.hasWindow,
            hasMultipleTabs: window.isInTabGroup,
            createTab: createWorkspaceTab,
            duplicateTab: duplicateCurrentTab,
            replaceWorkspace: { showingPicker = true },
            toggleToolbar: window.toggleToolbar
        )
    }

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            isSidebarVisible ? .all : .detailOnly
        } set: {
            isSidebarVisible = $0 != .detailOnly
        }
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
        RecentDocuments.shared.note(pdf)
        openAsTab(.duplicate(rootURL: rootURL, selectedPDF: pdf))
    }

    private func selectPDF(_ pdf: URL) {
        session.select(pdf)
        RecentDocuments.shared.note(pdf)
    }

    private func open(_ url: URL) {
        session.open(url)
        RecentDocuments.shared.note(url)
        showingWelcome = false
    }

    private func openRecentPDF(_ pdf: URL) {
        if session.containsPDF(pdf) {
            selectPDF(pdf)
        } else {
            open(pdf)
        }
    }

    private var workspaceRecentPDFs: [URL] {
        Array(
            recentDocuments.urls.lazy
                .filter { session.containsPDF($0) }
                .prefix(5)
        )
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

    private func saveRestorationState() {
        let state = WorkspaceLaunch(
            id: restorationID,
            rootURL: session.rootURL,
            selectedPDF: session.selectedPDF,
            lastSelectedPDF: showingWelcome ? lastSelectedPDF : nil,
            presentsPicker: false,
            startsAtWelcome: showingWelcome
        )
        if restoration != state {
            restoration = state
        }
    }
}

#if DEBUG
#Preview("Demo PDF") {
    WorkspaceView(initialPDF: DevelopmentConfiguration.demoPDFURL)
}
#endif
