import AppKit
import SwiftUI

final class LaunchPanelController: NSWindowController {
    var onOpen: (() -> Void)?
    var onSelectWorkspace: ((URL) -> Void)?
    var onSelectPDF: ((URL) -> Void)?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.setContentSize(NSSize(width: 680, height: 420))
        panel.minSize = NSSize(width: 680, height: 420)
        panel.maxSize = NSSize(width: 680, height: 420)
        panel.center()

        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: panel)

        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        configureContent()
    }

    private func configureContent() {
        let store = RecentLocationsStore.shared
        let view = LaunchPanelView(
            recentWorkspaces: Array(store.recentWorkspaces.prefix(10)),
            recentPDFs: Array(store.recentPDFs.prefix(10)),
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
        window?.setContentSize(NSSize(width: 680, height: 420))
    }
}
