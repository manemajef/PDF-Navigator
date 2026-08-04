import AppKit
import Combine
import SwiftUI

final class WindowContentController: NSSplitViewController {
    private let session: TabSession
    private let sidebarController: NSHostingController<SidebarView>
    private let pdfReaderController = PDFReaderController()
    private let workspaceHomeController: WorkspaceHomeController
    private let contentHostController = NSViewController()
    private var sessionChangesSubscription: AnyCancellable?

    var readerController: PDFReaderController {
        pdfReaderController
    }

    init(session: TabSession, actions: WindowActions) {
        self.session = session
        let sidebarViewModel = SidebarViewModel()
        self.sidebarController = NSHostingController(
            rootView: SidebarView(
                viewModel: sidebarViewModel,
                onSelectPDF: { session.select($0) },
                onOpenInNewTab: { actions.openInNewTab($0) },
                onOpenInDefaultApp: { NSWorkspace.shared.open($0) },
                onShowInFinder: { NSWorkspace.shared.activateFileViewerSelecting([$0]) },
                onSearch: {
                    NSApp.sendAction(
                        #selector(WindowController.beginSearch(_:)),
                        to: nil,
                        from: nil
                    )
                }
            )
        )
        self.workspaceHomeController = WorkspaceHomeController(actions: actions)
        super.init(nibName: nil, bundle: nil)

        sidebarViewModel.bind(to: session)

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

        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarController)
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
            content.automaticallyAdjustsSafeAreaInsets = true
        }

        addSplitViewItem(sidebar)
        addSplitViewItem(content)
        splitView.autosaveName = "WorkspaceSplitView"

        renderMode()
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

#if DEBUG
private struct WindowContentPreview: NSViewControllerRepresentable {
    let request: OpenRequest

    func makeNSViewController(context: Context) -> WindowContentController {
        WindowContentController(
            session: TabSession(request: request),
            actions: WindowActions()
        )
    }

    func updateNSViewController(
        _ nsViewController: WindowContentController,
        context: Context
    ) {}
}

#Preview("Workspace Shell — Home") {
    WindowContentPreview(request: .folder(DevelopmentConfiguration.demoDirURL))
        .frame(width: 850, height: 600)
}

#Preview("Workspace Shell — Reading") {
    WindowContentPreview(request: .pdf(DevelopmentConfiguration.demoPDFURL))
        .frame(width: 850, height: 600)
}
#endif
