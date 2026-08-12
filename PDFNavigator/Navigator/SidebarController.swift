import AppKit
import SwiftUI

/// Native sidebar shell containing the AppKit navigator and SwiftUI footer.
final class SidebarController: NSViewController {
    private let session: WorkspaceSession
    private let actions: WindowActions
    private let footerView: NSHostingView<SidebarFooterView>
    private var itemCount: Int?
    private lazy var navigatorController = NavigatorController(
        rootURL: session.root,
        mode: session.mode,
        onSelectPDF: session.show,
        onSelectFolder: session.showFolder,
        onOpenInNewTab: actions.openInNewTab,
        onItemCountChange: { [weak self] in self?.setItemCount($0) }
    )

    init(session: WorkspaceSession, actions: WindowActions) {
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
        // `addChild` puts the navigator in the responder chain and retains it.
        // Adding only its view yields a sidebar that draws but answers nothing.
        addChild(navigatorController)

        // Outline on top, footer beneath.
        let column = NSStackView(views: [navigatorController.view, footerView])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 0
        column.distribution = .fill

        // The footer is content-sized and the outline takes whatever is left.
        footerView.setContentHuggingPriority(.required, for: .vertical)
        navigatorController.view.setContentHuggingPriority(.defaultLow, for: .vertical)
        footerView.widthAnchor
            .constraint(equalTo: column.widthAnchor)
            .isActive = true
        view = column
    }

    func render() {
        footerView.rootView = makeFooter()
        navigatorController.render(
            rootURL: session.root,
            mode: session.mode
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
