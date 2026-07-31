import AppKit

final class WorkspaceSplitViewController: NSSplitViewController {
    private let navigatorController = NavigatorController()
    private let pdfReaderController: PDFReaderController
    private let welcomeController: WelcomeController
    private let workspaceHomeController: WorkspaceHomeController
    private let contentHostController = NSViewController()

    var onSelectPDF: ((URL) -> Void)? {
        get { navigatorController.onSelectPDF }
        set { navigatorController.onSelectPDF = newValue }
    }

    var onOpenPDFInNewTab: ((URL) -> Void)? {
        get { navigatorController.onOpenPDFInNewTab }
        set { navigatorController.onOpenPDFInNewTab = newValue }
    }

    init(
        pdfReaderController: PDFReaderController,
        welcomeController: WelcomeController,
        workspaceHomeController: WorkspaceHomeController
    ) {
        self.pdfReaderController = pdfReaderController
        self.welcomeController = welcomeController
        self.workspaceHomeController = workspaceHomeController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // sidebar
        let sidebar = NSSplitViewItem(sidebarWithViewController: navigatorController)
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 360
        sidebar.canCollapse = true
        sidebar.canCollapseFromWindowResize = false
        sidebar.allowsFullHeightLayout = true
        sidebar.titlebarSeparatorStyle = .none

        // content
        contentHostController.view = NSView()
        let content = NSSplitViewItem(viewController: contentHostController)
        content.minimumThickness = 420
        content.titlebarSeparatorStyle = .shadow
        
        
        if #available(macOS 26.0, *) {
            content.automaticallyAdjustsSafeAreaInsets = true //toggle to disable floating sidebar effect
        }

        // compose sidebar and content
        addSplitViewItem(sidebar)
        addSplitViewItem(content)
        splitView.autosaveName = "WorkspaceSplitView"
    }

    func display(workspaceRootURL: URL?, selectedPDFURL: URL?) {
        loadViewIfNeeded()
        navigatorController.display(
            workspaceRootURL: workspaceRootURL,
            selectedPDFURL: selectedPDFURL
        )

        if let selectedPDFURL {
            showPDF(selectedPDFURL)
        } else if let workspaceRootURL {
            showWorkspaceHome(workspaceRootURL)
        } else {
            showWelcome()
        }
    }

    func selectPDF(_ url: URL) {
        loadViewIfNeeded()
        navigatorController.setSelectedPDF(url)
        showPDF(url)
    }

    private func showPDF(_ url: URL) {
        installContentController(pdfReaderController)
        pdfReaderController.display(url)
    }

    private func showWelcome() {
        welcomeController.refresh()
        installContentController(welcomeController)
    }

    private func showWorkspaceHome(_ workspaceRootURL: URL) {
        workspaceHomeController.display(workspaceRootURL: workspaceRootURL)
        installContentController(workspaceHomeController)
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
