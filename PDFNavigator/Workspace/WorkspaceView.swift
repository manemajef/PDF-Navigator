import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @Environment(\.openWindow) private var openWindow

    @StateObject private var session: WorkspaceSession
    @StateObject private var windowController:
        WorkspaceWindowController
    @StateObject private var readerController =
        PDFReaderController()

    @State private var showingWorkspacePicker = false
    @State private var hasPresentedInitialPicker = false
    @State private var searchText = ""

    private let presentsWorkspacePicker: Bool

    init(
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil,
        sourceWindowNumber: Int? = nil,
        presentsWorkspacePicker: Bool = false
    ) {
        self.presentsWorkspacePicker =
            presentsWorkspacePicker
        _session = StateObject(
            wrappedValue: WorkspaceSession(
                initialPDF: initialPDF,
                initialWorkspace: initialWorkspace
            )
        )
        _windowController = StateObject(
            wrappedValue: WorkspaceWindowController(
                sourceWindowNumber: sourceWindowNumber
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            reader
                .ignoresSafeArea(.container, edges: .top)
        }
        .toolbar {
            workspaceToolbar
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Search Current PDF"
        )
        .searchToolbarBehavior(.automatic)
        .workspaceToolbarAppearance(
            isToolbarHidden:
                !windowController.isToolbarVisible
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
            isPresented: $session.showingError
        ) {
            Button("OK") {
                session.showingError = false
            }
        } message: {
            Text(session.errorMessage)
        }
        .background {
            WindowAccessor { window in
                windowController.resolve(
                    window,
                    onCreateWorkspaceTab:
                        createWorkspaceTab
                )
            }
        }
        .focusedSceneValue(
            \.workspaceCommandActions,
            commandActions
        )
        .onChange(
            of: windowController.windowNumber,
            initial: true
        ) { _, windowNumber in
            guard windowNumber != nil else {
                return
            }

            presentInitialWorkspacePickerIfNeeded()
        }
    }

    private var workspaceToolbar: WorkspaceToolbar {
        WorkspaceToolbar(
            canGoBack: session.canGoBack,
            canGoForward: session.canGoForward,
            onGoBack: session.goBack,
            onGoForward: session.goForward
        )
    }

    private var commandActions: WorkspaceCommandActions {
        WorkspaceCommandActions(
            canCreateWorkspaceTab:
                canCreateWorkspaceTab,
            canDuplicateTab: canDuplicateTab,
            isToolbarVisible:
                windowController.isToolbarVisible,
            createWorkspaceTab: createWorkspaceTab,
            duplicateTab: duplicateCurrentTab
        )
    }

    private var canCreateWorkspaceTab: Bool {
        windowController.windowNumber != nil
    }

    private var canDuplicateTab: Bool {
        canCreateWorkspaceTab
            && session.selectedPDF != nil
            && session.workspaceURL != nil
    }

    private var sidebar: some View {
        NavigatorView(
            nodes: session.navigatorNodes,
            selectedPDF: session.selectedPDF,
            canCreateWorkspaceTab: canCreateWorkspaceTab,
            canDuplicateTab: canDuplicateTab,
            onCreateWorkspaceTab: createWorkspaceTab,
            onDuplicateTab: duplicateCurrentTab,
            onSelectPDF: { pdf in
                session.select(pdf: pdf)
            },
            onOpenPDFInNewTab: { pdf in
                openPDFInNewTab(pdf)
            }
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
        if let selectedPDF = session.selectedPDF {
            PDFReaderView(
                url: selectedPDF,
                searchText: searchText,
                controller: readerController
            )
                .navigationTitle(selectedPDF.lastPathComponent)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                Text("No Workspace Open")
                    .font(.title2)

                Text("Choose a folder or PDF to begin.")
                    .foregroundStyle(.secondary)

                Button("Open Workspace") {
                    showingWorkspacePicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func createWorkspaceTab() {
        guard let sourceWindowNumber =
            windowController.windowNumber
        else {
            return
        }

        let configuration =
            WorkspaceWindowConfiguration.newWorkspaceTab(
                sourceWindowNumber: sourceWindowNumber
            )

        openWindow(
            value: configuration
        )
    }

    private func duplicateCurrentTab() {
        guard let selectedPDF = session.selectedPDF else {
            return
        }

        openPDFInNewTab(selectedPDF)
    }

    private func openPDFInNewTab(_ pdf: URL) {
        guard
            let sourceWindowNumber =
                windowController.windowNumber,
            let workspaceURL = session.workspaceURL
        else {
            return
        }

        openWindow(
            value: WorkspaceWindowConfiguration.duplicateTab(
                workspaceURL: workspaceURL,
                selectedPDF: pdf,
                sourceWindowNumber: sourceWindowNumber
            )
        )
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
        } catch {
            session.errorMessage = error.localizedDescription
            session.showingError = true
        }
    }

    private func presentInitialWorkspacePickerIfNeeded() {
        guard
            presentsWorkspacePicker,
            !hasPresentedInitialPicker
        else {
            return
        }

        hasPresentedInitialPicker = true
        showingWorkspacePicker = true
    }
}

#if DEBUG
#Preview {
    WorkspaceView(
        initialPDF: DevelopmentConfiguration.demoPDFURL
    )
}
#endif
