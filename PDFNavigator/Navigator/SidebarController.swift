import AppKit
import SwiftUI

/// Native sidebar shell containing the AppKit navigator and SwiftUI footer.
final class SidebarController: NSViewController {
    private let session: TabSession
    private let actions: WorkspaceActions
    private let footerView: NSHostingView<SidebarFooterView>
    private var itemCount: Int?
    private lazy var navigatorController = NavigatorController(
        rootURL: session.root,
        selectedPDFURL: session.selection,
        onSelectPDF: session.select,
        onOpenInNewTab: actions.openInNewTab,
        onItemCountChange: { [weak self] in self?.setItemCount($0) }
    )

    init(session: TabSession, actions: WorkspaceActions) {
        self.session = session
        self.actions = actions
        footerView = NSHostingView(
            rootView: SidebarFooterView {
                actions.revealInFinder(session.root)
            }
        )
        super.init(nibName: nil, bundle: nil)
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
}
