import AppKit
import PDFKit
import SwiftUI

/// Native three-column geometry: Navigator | workspace/reader | Inspector.
final class WorkspaceSplitController: NSSplitViewController {
    private let session: TabSession
    private let readerController: PDFReaderController
    private let workspaceSidebarController: SidebarController
    private let workspaceController: NSHostingController<WorkspaceHomeContentView>
    private let inspectorPresentationState = PDFInspectorPresentationState()
    private let onInspectorPresentationChange: (Bool, PDFInspectorSection) -> Void
    private let detailContainer = NSViewController()
    private let inspectorSidebarContainer = NSViewController()

    private var workspaceSidebarItem: NSSplitViewItem!
    private var inspectorSidebarItem: NSSplitViewItem!
    private var didApplyInitialInspectorVisibility = false

    private var inspectorController: NSHostingController<PDFInspectorView>?

    init(
        session: TabSession,
        actions: WorkspaceActions,
        readerController: PDFReaderController,
        onInspectorPresentationChange: @escaping (Bool, PDFInspectorSection) -> Void
    ) {
        self.session = session
        self.readerController = readerController
        self.onInspectorPresentationChange = onInspectorPresentationChange

        workspaceSidebarController = SidebarController(session: session, actions: actions)
        workspaceController = NSHostingController(
            rootView: WorkspaceHomeContentView(
                session: session,
                actions: actions
            )
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

        renderMode()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard !didApplyInitialInspectorVisibility else { return }
        didApplyInitialInspectorVisibility = true
        inspectorSidebarItem.isCollapsed = true
    }

    func renderMode() {
        loadViewIfNeeded()
        workspaceSidebarController.update()

        switch session.mode {
        case .workspaceHome:
            inspectorSidebarItem.isCollapsed = true
            notifyInspectorPresentation(isVisible: false)
            install(workspaceController, in: detailContainer)

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
        let isVisible = inspectorSidebarItem.isCollapsed
        inspectorSidebarItem.animator().isCollapsed = !isVisible
        notifyInspectorPresentation(isVisible: isVisible)
    }

    func toggleInspectorSection(_ section: PDFInspectorSection) {
        guard session.pdfSession?.hasDocument == true else { return }

        let isCurrentPanel = inspectorPresentationState.section == section
        let shouldCollapse = !inspectorSidebarItem.isCollapsed
            && isCurrentPanel
        inspectorSidebarItem.animator().isCollapsed = shouldCollapse
        if !shouldCollapse {
            inspectorPresentationState.section = section
        }
        notifyInspectorPresentation(isVisible: !shouldCollapse)
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
                self?.notifyInspectorPresentation()
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

    private func notifyInspectorPresentation(isVisible: Bool? = nil) {
        onInspectorPresentationChange(
            isVisible ?? !inspectorSidebarItem.isCollapsed,
            inspectorPresentationState.section
        )
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
