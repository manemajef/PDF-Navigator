import AppKit
import Combine

final class WindowContentController: NSSplitViewController {
    private let session: TabSession
    private let navigatorController: NavigatorController
    private let pdfReaderController = PDFReaderController()
    private let welcomeController: WelcomeController
    private let workspaceHomeController: WorkspaceHomeController
    private let contentHostController = NSViewController()
    private var sessionChangesSubscription: AnyCancellable?

    var readerController: PDFReaderController {
        pdfReaderController
    }

    init(session: TabSession, actions: WindowActions) {
        self.session = session
        self.navigatorController = NavigatorController(session: session, actions: actions)
        self.welcomeController = WelcomeController(actions: actions)
        self.workspaceHomeController = WorkspaceHomeController(actions: actions)
        super.init(nibName: nil, bundle: nil)

        sessionChangesSubscription = session.changes.sink { [weak self] change in
            guard change == .selection else { return }
            self?.renderMode()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebar = NSSplitViewItem(sidebarWithViewController: navigatorController)
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 360
        sidebar.canCollapse = true
        sidebar.canCollapseFromWindowResize = false
        sidebar.allowsFullHeightLayout = true
        sidebar.titlebarSeparatorStyle = .none

        contentHostController.view = NSView()
        let content = NSSplitViewItem(viewController: contentHostController)
        content.minimumThickness = 420
        content.titlebarSeparatorStyle = .shadow

        if #available(macOS 26.0, *) {
            // Keep detail content beside the full-height sidebar instead of underneath it.
            content.automaticallyAdjustsSafeAreaInsets = true
        }

        addSplitViewItem(sidebar)
        addSplitViewItem(content)
        splitView.autosaveName = "WorkspaceSplitView"
    }

    private func renderMode() {
        loadViewIfNeeded()

        switch session.mode {
        case .reading:
            guard let pdfSession = session.pdfSession else { return }
            installContentController(pdfReaderController)
            pdfReaderController.display(pdfSession)

        case .workspaceHome(let root):
            workspaceHomeController.display(workspaceRootURL: root)
            installContentController(workspaceHomeController)

        case .welcome:
            welcomeController.refresh()
            installContentController(welcomeController)
        }
    }

    private func installContentController(_ controller: NSViewController) {
        guard contentHostController.children.first !== controller else { return }

        for child in contentHostController.children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        contentHostController.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        contentHostController.view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: contentHostController.view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: contentHostController.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: contentHostController.view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: contentHostController.view.bottomAnchor)
        ])
    }
}
