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

    @State private var shellState: WorkspaceShellState
    @State private var restorationID: UUID
    @State private var showingPicker = false
    @State private var presentedInitialPicker = false
    @State private var searchText = ""
    @State private var showingWelcome: Bool

    private let presentsPicker: Bool
    private let lastSelectedPDF: URL?
    private let openTabWithAppKit:
        ((WorkspaceLaunch, WorkspaceShellState, NSWindow) -> Void)?
    private let onWindowReady: ((NSWindow) -> Void)?

    init(
        restoration: Binding<WorkspaceLaunch?> = .constant(nil),
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        lastSelectedPDF: URL? = nil,
        launchID: UUID? = nil,
        initialShellState: WorkspaceShellState? = nil,
        presentsPicker: Bool = false,
        startsAtWelcome: Bool = false,
        openTabWithAppKit:
            ((WorkspaceLaunch, WorkspaceShellState, NSWindow) -> Void)? = nil,
        onWindowReady: ((NSWindow) -> Void)? = nil
    ) {
        _restoration = restoration
        self.presentsPicker = presentsPicker
        self.lastSelectedPDF = lastSelectedPDF
        self.openTabWithAppKit = openTabWithAppKit
        self.onWindowReady = onWindowReady
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
        let window = WindowBridge(launchID: launchID)
        _window = StateObject(wrappedValue: window)
        _shellState = State(
            initialValue: initialShellState
                ?? window.inheritedShellState
                ?? WorkspaceShellState()
        )
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
        .toolbarVisibility(
            shellState.isToolbarVisible ? .automatic : .hidden,
            for: .windowToolbar
        )
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
            WindowReader { resolvedWindow in
                window.resolve(resolvedWindow)
                onWindowReady?(resolvedWindow)
            }
        }
        .focusedSceneValue(\.workspaceActions, actions)
        .modifier(
            ExternalURLHandler(
                isEnabled: openTabWithAppKit == nil,
                action: open
            )
        )
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
        if !showingWelcome && session.isLoading && session.items.isEmpty {
            ProgressView("Loading Workspace…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !showingWelcome, let pdf = session.selectedPDF {
            PDFReaderView(
                url: pdf,
                searchText: searchText,
                handle: reader
            )
        } else {
            WorkspaceWelcomeView(
                recentPDFs: Array(recentDocuments.urls.prefix(5)),
                onOpenRecentPDF: openRecentPDF,
                onLoadNewWorkspace: {
                    showingPicker = true
                }
            )
        }
    }

    private var actions: WorkspaceActions {
        WorkspaceActions(
            session: session,
            reader: reader,
            canCreateTab: window.hasWindow,
            createTab: createWorkspaceTab,
            replaceWorkspace: { showingPicker = true },
            toggleToolbar: {
                shellState.isToolbarVisible.toggle()
            }
        )
    }

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            shellState.isSidebarVisible ? .all : .detailOnly
        } set: {
            shellState.isSidebarVisible = $0 != .detailOnly
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

    private func openPDFInNewTab(_ pdf: URL) {
        guard let rootURL = session.rootURL else { return }
        RecentDocuments.shared.note(pdf)
        openAsTab(
            .openingPDF(
                rootURL: rootURL,
                selectedPDF: pdf
            )
        )
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

    private func openAsTab(_ launch: WorkspaceLaunch) {
        if let openTabWithAppKit, let sourceWindow = window.window {
            openTabWithAppKit(launch, shellState, sourceWindow)
            return
        }

        guard window.registerAsTabSource(
            for: launch.id,
            shellState: shellState
        ) else { return }
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

private struct ExternalURLHandler: ViewModifier {
    let isEnabled: Bool
    let action: (URL) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.onOpenURL(perform: action)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Demo PDF") {
    WorkspaceView(initialPDF: DevelopmentConfiguration.demoPDFURL)
}
#endif
