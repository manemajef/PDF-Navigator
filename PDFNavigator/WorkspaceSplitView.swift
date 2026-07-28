import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceSplitView: View {
    @Environment(\.openWindow) private var openWindow

    @StateObject private var session: WorkspaceSession
    @StateObject private var windowCoordinator:
        WorkspaceWindowCoordinator
    @StateObject private var readerController =
        PDFReaderController()

    @State private var showingWorkspacePicker = false
    @State private var hasPresentedInitialPicker = false
    @State private var searchText = ""
    @State private var isShowingWelcome: Bool

    private let presentsWorkspacePicker: Bool
    private let lastSelectedPDF: URL?

    init(
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        lastSelectedPDF: URL? = nil,
        launchContextID: UUID? = nil,
        presentsWorkspacePicker: Bool = false,
        startsAtWelcome: Bool = false
    ) {
        self.presentsWorkspacePicker =
            presentsWorkspacePicker
        self.lastSelectedPDF = lastSelectedPDF
        _session = StateObject(
            wrappedValue: WorkspaceSession(
                initialPDF: initialPDF,
                initialWorkspace: initialWorkspace,
                selectsInitialPDF: !startsAtWelcome
            )
        )
        _windowCoordinator = StateObject(
            wrappedValue: WorkspaceWindowCoordinator(
                launchContextID: launchContextID
            )
        )
        _isShowingWelcome = State(
            initialValue: startsAtWelcome
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            reader
                .ignoresSafeArea(.container, edges: .top)
                .toolbarRole(.editor)
                .toolbar {
                    WorkspaceToolbar(
                        actions: workspaceActions,
                        showsPrimaryNewTabAction:
                            !windowCoordinator.isInTabGroup,
                        showsTabActions: false
                    )
                }
                .searchable(
                    text: $searchText,
                    placement: .toolbar,
                    prompt: "Search Current PDF"
                )
        }
        .workspaceToolbarAppearance(
            isToolbarHidden:
                !windowCoordinator.isToolbarVisible
        )
        .fileImporter(
            isPresented: $showingWorkspacePicker,
            allowedContentTypes: [.folder, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleWorkspaceSelection(result)
        }
        .alert(
            "Couldn’t Open Workspace",
            isPresented: errorPresentation,
            presenting: session.presentedError
        ) { _ in
            Button("OK", action: session.dismissError)
        } message: { message in
            Text(message)
        }
        .background {
            WorkspaceWindowReader { window in
                windowCoordinator.resolve(
                    window,
                    onCreateWorkspaceTab: createWorkspaceTab
                )
            }
        }
        .focusedSceneValue(
            \.workspaceActions,
            workspaceActions
        )
        .onChange(
            of: windowCoordinator.hasWindow,
            initial: true
        ) { _, hasWindow in
            guard hasWindow else {
                return
            }

            presentInitialWorkspacePickerIfNeeded()
        }
    }

    private var workspaceActions: WorkspaceActions {
        WorkspaceActions(
            canGoBack: session.canGoBack,
            canGoForward: session.canGoForward,
            canCreateWorkspaceTab:
                canCreateWorkspaceTab,
            canDuplicateTab: canDuplicateTab,
            goBack: session.goBack,
            goForward: session.goForward,
            createWorkspaceTab: createWorkspaceTab,
            duplicateTab: duplicateCurrentTab,
            reader: PDFReaderActions(
                capabilities:
                    readerController.capabilities,
                goToPreviousPage:
                    readerController.goToPreviousPage,
                goToNextPage:
                    readerController.goToNextPage,
                goBack: readerController.goBack,
                goForward: readerController.goForward,
                zoomIn: readerController.zoomIn,
                zoomOut: readerController.zoomOut,
                showActualSize:
                    readerController.showActualSize,
                zoomToFit: readerController.zoomToFit
            )
        )
    }

    private var canCreateWorkspaceTab: Bool {
        windowCoordinator.hasWindow
    }

    private var canDuplicateTab: Bool {
        canCreateWorkspaceTab
            && session.selectedPDF != nil
            && session.workspaceURL != nil
    }

    private var sidebar: some View {
        SidebarView(
            nodes: session.navigatorNodes,
            selectedPDF: session.selectedPDF,
            showsFooter: false,
            canCreateWorkspaceTab: canCreateWorkspaceTab,
            canDuplicateTab: canDuplicateTab,
            onCreateWorkspaceTab: createWorkspaceTab,
            onDuplicateTab: duplicateCurrentTab,
            onSelectPDF: { pdf in
                session.select(pdf: pdf)
                isShowingWelcome = false
            },
            onOpenPDFInNewTab: { pdf in
                openPDFInNewTab(pdf)
            },
            onExpandDirectory: session.expand
        )
        .navigationTitle(session.folderName)
        .navigationSplitViewColumnWidth(
            min: 180,
            ideal: 240,
            max: 350
        )
    }

    @ViewBuilder
    private var reader: some View {
        if isShowingWelcome {
            WorkspaceWelcomeView(
                workspaceName: session.folderName,
                lastSelectedPDF: lastSelectedPDF,
                hasWorkspace: session.workspaceURL != nil,
                onOpenLastPDF: openLastPDF,
                onLoadNewWorkspace: {
                    showingWorkspacePicker = true
                }
            )
        } else {
            switch session.state {
            case .empty:
                WorkspaceEmptyView {
                    showingWorkspacePicker = true
                }
            case .loading:
                ProgressView("Loading Workspace…")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            case .failed(_, let message):
                ContentUnavailableView(
                    "Couldn’t Open Workspace",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .active(let workspace):
                if let selectedPDF = workspace.selectedPDF {
                    PDFReaderView(
                        url: selectedPDF,
                        searchText: searchText,
                        controller: readerController
                    )
                    .navigationTitle(
                        selectedPDF.lastPathComponent
                    )
                } else {
                    WorkspaceEmptyView {
                        showingWorkspacePicker = true
                    }
                }
            }
        }
    }

    private var errorPresentation: Binding<Bool> {
        Binding(
            get: {
                session.presentedError != nil
            },
            set: { isPresented in
                if !isPresented {
                    session.dismissError()
                }
            }
        )
    }

    private func createWorkspaceTab() {
        let configuration =
            WorkspaceLaunchContext.newWorkspaceTab(
                workspaceURL: session.workspaceURL,
                lastSelectedPDF: session.selectedPDF
            )

        openAsTab(configuration)
    }

    private func duplicateCurrentTab() {
        guard let selectedPDF = session.selectedPDF else {
            return
        }

        openPDFInNewTab(selectedPDF)
    }

    private func openPDFInNewTab(_ pdf: URL) {
        guard let workspaceURL = session.workspaceURL else {
            return
        }

        openAsTab(
            WorkspaceLaunchContext.duplicateTab(
                workspaceURL: workspaceURL,
                selectedPDF: pdf
            )
        )
    }

    private func openAsTab(
        _ configuration: WorkspaceLaunchContext
    ) {
        guard windowCoordinator.registerAsTabSource(
            for: configuration.id
        ) else {
            return
        }

        openWindow(value: configuration)
    }

    private func handleWorkspaceSelection(
        _ result: Result<[URL], Error>
    ) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let values = try url.resourceValues(
                forKeys: [.isDirectoryKey]
            )

            if values.isDirectory == true {
                session.open(folder: url)
            } else {
                session.open(pdf: url)
            }

            isShowingWelcome = false
        } catch {
            session.report(error)
        }
    }

    private func presentInitialWorkspacePickerIfNeeded() {
        guard
            presentsWorkspacePicker,
            session.workspaceURL == nil,
            !hasPresentedInitialPicker
        else {
            return
        }

        hasPresentedInitialPicker = true
        showingWorkspacePicker = true
    }

    private func openLastPDF() {
        guard let lastSelectedPDF else {
            return
        }

        session.select(pdf: lastSelectedPDF)
        isShowingWelcome = false
    }
}

#if DEBUG
#Preview("Empty Workspace") {
    WorkspaceSplitView()
}
#endif
