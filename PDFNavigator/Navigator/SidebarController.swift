import AppKit
import SwiftUI

/// Native sidebar shell containing the AppKit navigator and SwiftUI footer.
final class SidebarController: NSViewController {
    private let session: TabSession
    private let actions: WorkspaceActions
    private let navigatorController: NavigatorController
    private let headerView: NSHostingView<SidebarHeaderView>
    private let footerView: NSHostingView<SidebarFooterView>
    private var itemCount: Int?

    init(session: TabSession, actions: WorkspaceActions) {
        self.session = session
        self.actions = actions
        navigatorController = NavigatorController(
            rootURL: session.root,
            selectedPDFURL: session.selection,
            onSelectPDF: session.select,
            onOpenInNewTab: actions.openInNewTab,
            onItemCountChange: { _ in }
        )
        headerView = NSHostingView(
            rootView: SidebarHeaderView(
                title: Self.workspaceName(session.root),
                isSearchEnabled: session.pdfSession?.hasDocument == true,
                onSearch: actions.beginSearch
            )
        )
        footerView = NSHostingView(
            rootView: SidebarFooterView {
                actions.revealInFinder(session.root)
            }
        )
        super.init(nibName: nil, bundle: nil)

        navigatorController.update(
            rootURL: session.root,
            selectedPDFURL: session.selection,
            onSelectPDF: session.select,
            onOpenInNewTab: actions.openInNewTab,
            onItemCountChange: { [weak self] in self?.setItemCount($0) }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func loadView() {
        let container = NSView()
        addChild(navigatorController)
        for childView in [navigatorController.view, footerView] {
            childView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(childView)
        }

        NSLayoutConstraint.activate([
//            headerView.topAnchor.constraint(equalTo: container.topAnchor),
//            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
//            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            navigatorController.view.topAnchor.constraint(equalTo: container.topAnchor),
            navigatorController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            navigatorController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footerView.topAnchor.constraint(equalTo: navigatorController.view.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container
    }

    func update() {
//        headerView.rootView = SidebarHeaderView(
//            title: Self.workspaceName(session.root),
//            isSearchEnabled: session.pdfSession?.hasDocument == true,
//            onSearch: actions.beginSearch
//        )
        footerView.rootView = makeFooter()
        navigatorController.update(
            rootURL: session.root,
            selectedPDFURL: session.selection,
            onSelectPDF: session.select,
            onOpenInNewTab: actions.openInNewTab,
            onItemCountChange: { [weak self] in self?.setItemCount($0) }
        )
    }

    private func setItemCount(_ count: Int?) {
        itemCount = count
        footerView.rootView = makeFooter()
    }

    private func makeFooter() -> SidebarFooterView {
        SidebarFooterView(itemCount: itemCount) { [session, actions] in
            actions.revealInFinder(session.root)
        }
    }

    private static func workspaceName(_ url: URL) -> String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}
