import AppKit
import SwiftUI

/// Native window geometry with a SwiftUI home and a direct PDFKit reader.
final class WorkspaceSplitController: NSSplitViewController {
    private let session: TabSession
    private let readerController: PDFReaderController
    private let sidebarController: SidebarController
    private let workspaceController: NSHostingController<WorkspaceHomeContentView>
    private let detailContainer = NSViewController()

    init(
        session: TabSession,
        actions: WorkspaceActions,
        readerController: PDFReaderController
    ) {
        self.session = session
        self.readerController = readerController

        sidebarController = SidebarController(session: session, actions: actions)
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

        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 360
        sidebar.canCollapse = true
        sidebar.canCollapseFromWindowResize = false
        sidebar.allowsFullHeightLayout = true
        sidebar.titlebarSeparatorStyle = .none

        detailContainer.view = NSView()
        let detail = NSSplitViewItem(viewController: detailContainer)
        detail.minimumThickness = 420
        detail.titlebarSeparatorStyle = .shadow
        if #available(macOS 26.0, *) {
            detail.automaticallyAdjustsSafeAreaInsets = true
        }

        addSplitViewItem(sidebar)
        addSplitViewItem(detail)
        splitView.autosaveName = "WorkspaceSplitView"

        renderMode()
    }

    func renderMode() {
        loadViewIfNeeded()
        sidebarController.update()

        switch session.mode {
        case .workspaceHome:
            install(workspaceController)

        case .reading:
            guard let pdfSession = session.pdfSession else { return }
            readerController.display(pdfSession)
            install(readerController)
        }
    }

    private func install(_ controller: NSViewController) {
        guard detailContainer.children.first !== controller else { return }

        for child in detailContainer.children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        detailContainer.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(
                equalTo: detailContainer.view.topAnchor
            ),
            controller.view.leadingAnchor.constraint(
                equalTo: detailContainer.view.leadingAnchor
            ),
            controller.view.trailingAnchor.constraint(
                equalTo: detailContainer.view.trailingAnchor
            ),
            controller.view.bottomAnchor.constraint(
                equalTo: detailContainer.view.bottomAnchor
            ),
        ])
    }
}
