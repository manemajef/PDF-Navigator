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
        // `addChild` is what puts the navigator in the responder chain and
        // keeps it alive; adding its view alone would leave a sidebar that
        // draws correctly and answers nothing.
        addChild(navigatorController)

        // Reading order is layout order: outline on top, footer beneath.
        let column = NSStackView(views: [navigatorController.view, footerView])
        column.orientation = .vertical
        column.alignment = .width
        column.spacing = 0
        column.distribution = .fill

        // The footer is content-sized and the outline takes whatever is left.
        footerView.setContentHuggingPriority(.required, for: .vertical)
        navigatorController.view.setContentHuggingPriority(.defaultLow, for: .vertical)

        view = column
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
