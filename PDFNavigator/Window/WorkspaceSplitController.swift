import AppKit
import PDFKit
import SwiftUI

/// Native three-column geometry: Navigator | workspace/reader | Inspector.
final class WorkspaceSplitController: NSSplitViewController {
    private let session: TabSession
    private let readerController: PDFReaderController
    private let workspaceSidebarController: SidebarController
    private let workspaceController: NSHostingController<WorkspaceHomeContentView>
    private let detailContainer = NSViewController()
    private let inspectorSidebarContainer = NSViewController()

    private var workspaceSidebarItem: NSSplitViewItem!
    private var inspectorSidebarItem: NSSplitViewItem!
    private var didApplyInitialInspectorVisibility = false

    #if DEBUG
    private var inspectorSidebarDemoController: NSHostingController<InspectorSidebarDemoView>?
    #endif

    init(
        session: TabSession,
        actions: WorkspaceActions,
        readerController: PDFReaderController
    ) {
        self.session = session
        self.readerController = readerController

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
        workspaceSidebarItem.canCollapseFromWindowResize = false
        workspaceSidebarItem.allowsFullHeightLayout = true
        workspaceSidebarItem.titlebarSeparatorStyle = .none

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
        inspectorSidebarItem.allowsFullHeightLayout = true
//        inspectorSidebarItem.titlebarSeparatorStyle = .none
        inspectorSidebarItem.isCollapsed = true

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
            install(workspaceController, in: detailContainer)

        case .reading:
            guard let pdfSession = session.pdfSession else { return }

            #if DEBUG
            if DevelopmentConfiguration.showsInspectorSidebarDemo {
                installInspectorSidebarDemo(for: pdfSession)
            }
            #endif

            readerController.display(pdfSession)
            install(readerController, in: detailContainer)
        }
    }

    func toggleWorkspaceSidebar(_ sender: Any?) {
        workspaceSidebarItem.animator().isCollapsed.toggle()
    }

    func toggleInspectorSidebar(_ sender: Any?) {
        inspectorSidebarItem.animator().isCollapsed.toggle()
    }

    #if DEBUG
    private func installInspectorSidebarDemo(for session: PDFSession) {
        let view = InspectorSidebarDemoView(
            fileName: session.url.lastPathComponent,
            pageCount: session.document?.pageCount ?? 0,
            onSelectPage: { [weak readerController] pageIndex in
                readerController?.goToPage(at: pageIndex)
            }
        )

        if let inspectorSidebarDemoController {
            inspectorSidebarDemoController.rootView = view
            install(inspectorSidebarDemoController, in: inspectorSidebarContainer)
        } else {
            let controller = NSHostingController(rootView: view)
            inspectorSidebarDemoController = controller
            install(controller, in: inspectorSidebarContainer)
        }
    }
    #endif

    private func install(
        _ controller: NSViewController,
        in container: NSViewController
    ) {
        guard container.children.first !== controller else { return }

        for child in container.children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        container.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(controller.view)

        let leadingAnchor = container === detailContainer
            ? container.view.safeAreaLayoutGuide.leadingAnchor
            : container.view.leadingAnchor
        let trailingAnchor = container === detailContainer
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
