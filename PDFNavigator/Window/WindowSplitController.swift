import AppKit
import PDFKit
import SwiftUI

/// Native three-column geometry: Navigator | workspace/reader | Inspector.
final class WindowSplitController: NSSplitViewController {
    private let session: WorkspaceSession
    private let readerController: PDFReaderController
    private let workspaceSidebarController: SidebarController
    private let startPageController: NSHostingController<StartPageView>
    private let libraryController: NSHostingController<LibraryContentView>
    private let inspectorPresentationState = PDFInspectorPresentationState()

    /// Carries no payload: this controller owns inspector presentation, so
    /// listeners read `inspectorSection` for the current value.
    private let onInspectorChange: () -> Void

    /// Whether the inspector is on screen.
    ///
    /// Tracked separately from the split item: the collapse goes through an
    /// animator, so the item's own flag is unreliable at the moment of change.
    private var isInspectorVisible = false
    private let detailContainer = NSViewController()
    private let inspectorSidebarContainer = NSViewController()

    private var workspaceSidebarItem: NSSplitViewItem!
    private var inspectorSidebarItem: NSSplitViewItem!
    private var didApplyInitialInspectorVisibility = false

    private var inspectorController: NSHostingController<PDFInspectorView>?

    /// The panel the inspector is showing, or `nil` while it is collapsed.
    var inspectorSection: PDFInspectorSection? {
        isInspectorVisible ? inspectorPresentationState.section : nil
    }

    init(
        session: WorkspaceSession,
        actions: WindowActions,
        readerController: PDFReaderController,
        onInspectorChange: @escaping () -> Void
    ) {
        self.session = session
        self.readerController = readerController
        self.onInspectorChange = onInspectorChange

        workspaceSidebarController = SidebarController(session: session, actions: actions)
        startPageController = NSHostingController(
            rootView: StartPageView(
                recentURLs: RecentLocationsStore.shared.recentPDFs(in: session.root),
                onOpenPDF: session.show
            )
        )
        libraryController = NSHostingController(
            rootView: LibraryContentView(session: session)
        )

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        workspaceSidebarItem = NSSplitViewItem(
            sidebarWithViewController: workspaceSidebarController
        )
        workspaceSidebarItem.minimumThickness = 180
        workspaceSidebarItem.maximumThickness = 360
        workspaceSidebarItem.canCollapse = true
        workspaceSidebarItem.canCollapseFromWindowResize = true
        workspaceSidebarItem.allowsFullHeightLayout = true
        workspaceSidebarItem.titlebarSeparatorStyle = .none
        workspaceSidebarItem.collapseBehavior = .preferResizingSiblingsWithFixedSplitView

        detailContainer.view = NSView()
        let detailItem = NSSplitViewItem(viewController: detailContainer)
        detailItem.minimumThickness = 420
        detailItem.titlebarSeparatorStyle = .automatic
        if #available(macOS 26.0, *) {
            detailItem.automaticallyAdjustsSafeAreaInsets = true
        }

        inspectorSidebarContainer.view = NSView()
        inspectorSidebarItem = NSSplitViewItem(
            inspectorWithViewController: inspectorSidebarContainer
        )
        inspectorSidebarItem.minimumThickness = 180
        inspectorSidebarItem.maximumThickness = 300
        inspectorSidebarItem.canCollapse = true
        inspectorSidebarItem.canCollapseFromWindowResize = true
        inspectorSidebarItem.allowsFullHeightLayout = false
//        inspectorSidebarItem.titlebarSeparatorStyle = .none
        inspectorSidebarItem.isCollapsed = true
        inspectorSidebarItem.collapseBehavior = .preferResizingSiblingsWithFixedSplitView

        addSplitViewItem(workspaceSidebarItem)
        addSplitViewItem(detailItem)
        addSplitViewItem(inspectorSidebarItem)
        splitView.autosaveName = "WorkspaceSplitView-v3"

        render()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard !didApplyInitialInspectorVisibility else { return }
        didApplyInitialInspectorVisibility = true
        inspectorSidebarItem.isCollapsed = true
    }

    func render() {
        loadViewIfNeeded()
        workspaceSidebarController.render()

        switch session.mode {
        case .startPage:
            startPageController.rootView = StartPageView(
                recentURLs: RecentLocationsStore.shared.recentPDFs(in: session.root),
                onOpenPDF: session.show
            )
            setInspector(visible: false)
            install(startPageController, in: detailContainer)

        case .library:
            setInspector(visible: false)
            install(libraryController, in: detailContainer)

        case .reading:
            guard let pdfSession = session.pdfSession else { return }
            readerController.display(pdfSession)
            installInspector(for: pdfSession)
            install(
                readerController,
                in: detailContainer,
                underlapsSidebars: true
            )
        }
    }

    func toggleWorkspaceSidebar(_ sender: Any?) {
        workspaceSidebarItem.animator().isCollapsed.toggle()
    }

    func toggleInspectorSidebar(_ sender: Any?) {
        guard session.pdfSession?.hasDocument == true else { return }
        setInspector(visible: !isInspectorVisible)
    }

    func toggleInspectorSection(_ section: PDFInspectorSection) {
        guard session.pdfSession?.hasDocument == true else { return }

        // Clicking the panel you are already looking at closes the inspector.
        let isCurrentPanel = inspectorPresentationState.section == section
        let shouldClose = isInspectorVisible && isCurrentPanel
        if !shouldClose {
            inspectorPresentationState.section = section
        }
        setInspector(visible: !shouldClose)
    }

    /// The only place inspector visibility changes, so the flag and the split
    /// item cannot disagree.
    private func setInspector(visible: Bool) {
        isInspectorVisible = visible
        inspectorSidebarItem.animator().isCollapsed = !visible
        onInspectorChange()
    }

    private func installInspector(for session: PDFSession) {
        let view = PDFInspectorView(
            session: session,
            readerState: readerController.presentationState,
            presentationState: inspectorPresentationState,
            onSelectPage: { [weak readerController] pageIndex in
                readerController?.goToPage(at: pageIndex)
            },
            onSelectOutline: { [weak readerController] outline in
                readerController?.follow(outline)
            },
            onSectionChange: { [weak self] _ in
                self?.onInspectorChange()
            }
        )

        if let inspectorController {
            inspectorController.rootView = view
            install(inspectorController, in: inspectorSidebarContainer)
        } else {
            let controller = NSHostingController(rootView: view)
            controller.sizingOptions = []
            inspectorController = controller
            install(controller, in: inspectorSidebarContainer)
        }
    }

    private func install(
        _ controller: NSViewController,
        in container: NSViewController,
        underlapsSidebars: Bool = false
    ) {
        guard container.children.first !== controller else { return }

        for child in container.children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        container.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(controller.view)

        let usesDetailSafeArea = container === detailContainer && !underlapsSidebars
        let leadingAnchor = usesDetailSafeArea
            ? container.view.safeAreaLayoutGuide.leadingAnchor
            : container.view.leadingAnchor
        let trailingAnchor = usesDetailSafeArea
            ? container.view.safeAreaLayoutGuide.trailingAnchor
            : container.view.trailingAnchor

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: container.view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
        ])
    }
}
