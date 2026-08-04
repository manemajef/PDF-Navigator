import AppKit
import SwiftUI

final class LaunchPanelController: NSWindowController {
    var onOpen: (() -> Void)?
    var onSelectWorkspace: ((URL) -> Void)?
    var onSelectPDF: ((URL) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PDF Navigator"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        super.init(window: window)

        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func refresh() {
        configureContent()
    }

    private func configureContent() {
        let store = RecentLocationsStore.shared
        let view = LaunchPanelView(
            recentWorkspaces: store.recentWorkspaces,
            recentPDFs: store.recentPDFs,
            onOpen: { [weak self] in
                self?.onOpen?()
            },
            onSelectWorkspace: { [weak self] url in
                self?.onSelectWorkspace?(url)
            },
            onSelectPDF: { [weak self] url in
                self?.onSelectPDF?(url)
            }
        )

        let hostingController = NSHostingController(rootView: view)
        window?.contentViewController = hostingController
    }
}
