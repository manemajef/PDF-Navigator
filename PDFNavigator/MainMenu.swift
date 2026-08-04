import AppKit

final class MainMenu: NSObject, NSMenuDelegate {
    private let recentLocations: RecentLocationsStore
    private let onNewWindow: () -> Void
    private let onOpen: () -> Void
    private let onOpenRecentWorkspace: (URL) -> Void
    private let onOpenRecentPDF: (URL) -> Void

    init(
        recentLocations: RecentLocationsStore,
        onNewWindow: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onOpenRecentWorkspace: @escaping (URL) -> Void,
        onOpenRecentPDF: @escaping (URL) -> Void
    ) {
        self.recentLocations = recentLocations
        self.onNewWindow = onNewWindow
        self.onOpen = onOpen
        self.onOpenRecentWorkspace = onOpenRecentWorkspace
        self.onOpenRecentPDF = onOpenRecentPDF
    }

    func install() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit PDF Navigator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(
            withTitle: "New Window",
            action: #selector(newWindow(_:)),
            keyEquivalent: "n"
        ).target = self
        fileMenu.addItem(
            withTitle: "New Tab",
            action: #selector(WindowController.newTab(_:)),
            keyEquivalent: "t"
        )
        fileMenu.addItem(
            withTitle: "Open...",
            action: #selector(open(_:)),
            keyEquivalent: "o"
        ).target = self
        let openRecentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: "Open Recent")
        openRecentMenu.delegate = self
        openRecentItem.submenu = openRecentMenu
        fileMenu.addItem(openRecentItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(
            withTitle: "Toggle Sidebar",
            action: #selector(WindowController.toggleSidebar(_:)),
            keyEquivalent: "s"
        ).keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(
            withTitle: "Toggle Toolbar",
            action: #selector(NSWindow.toggleToolbarShown(_:)),
            keyEquivalent: "t"
        ).keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(
            withTitle: "Customize Toolbar…",
            action: #selector(WindowController.customizeToolbar(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            withTitle: "Actual Size",
            action: #selector(WindowController.showActualSize(_:)),
            keyEquivalent: "0"
        )
        viewMenu.addItem(
            withTitle: "Zoom to Fit",
            action: #selector(WindowController.zoomToFit(_:)),
            keyEquivalent: "9"
        )
        viewMenu.addItem(
            withTitle: "Zoom In",
            action: #selector(WindowController.zoomIn(_:)),
            keyEquivalent: "="
        )
        viewMenu.addItem(
            withTitle: "Zoom Out",
            action: #selector(WindowController.zoomOut(_:)),
            keyEquivalent: "-"
        )

        let navigateMenuItem = NSMenuItem()
        mainMenu.addItem(navigateMenuItem)
        let navigateMenu = NSMenu(title: "Navigate")
        navigateMenuItem.submenu = navigateMenu
        navigateMenu.addItem(
            withTitle: "Back",
            action: #selector(WindowController.goBack(_:)),
            keyEquivalent: "["
        )
        navigateMenu.addItem(
            withTitle: "Forward",
            action: #selector(WindowController.goForward(_:)),
            keyEquivalent: "]"
        )
        navigateMenu.addItem(.separator())
        navigateMenu.addItem(
            withTitle: "Previous Page",
            action: #selector(WindowController.goToPreviousPage(_:)),
            keyEquivalent: ""
        )
        navigateMenu.addItem(
            withTitle: "Next Page",
            action: #selector(WindowController.goToNextPage(_:)),
            keyEquivalent: ""
        )

        let findMenuItem = NSMenuItem()
        mainMenu.addItem(findMenuItem)
        let findMenu = NSMenu(title: "Find")
        findMenuItem.submenu = findMenu
        findMenu.addItem(
            withTitle: "Find...",
            action: #selector(WindowController.beginSearch(_:)),
            keyEquivalent: "f"
        )
        findMenu.addItem(
            withTitle: "Find Next",
            action: #selector(WindowController.selectNextSearchMatch(_:)),
            keyEquivalent: "g"
        )
        let previousMatchItem = findMenu.addItem(
            withTitle: "Find Previous",
            action: #selector(WindowController.selectPreviousSearchMatch(_:)),
            keyEquivalent: "g"
        )
        previousMatchItem.keyEquivalentModifierMask = [.command, .shift]

        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Open in Default App",
            action: #selector(WindowController.openCurrentPDFInDefaultApp(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: "Share...",
            action: #selector(WindowController.shareCurrentPDF(_:)),
            keyEquivalent: ""
        )

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: "Show Next Tab",
            action: #selector(NSWindow.selectNextTab(_:)),
            keyEquivalent: "}"
        )
        windowMenu.addItem(
            withTitle: "Show Previous Tab",
            action: #selector(NSWindow.selectPreviousTab(_:)),
            keyEquivalent: "{"
        )
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Open Recent" else { return }
        menu.removeAllItems()

        appendRecentSection(
            title: "Workspaces",
            urls: recentLocations.recentWorkspaces,
            action: #selector(openRecentWorkspace(_:)),
            to: menu
        )
        menu.addItem(.separator())
        appendRecentSection(
            title: "PDFs",
            urls: recentLocations.recentPDFs,
            action: #selector(openRecentPDF(_:)),
            to: menu
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Clear Menu",
            action: #selector(clearRecentLocations(_:)),
            keyEquivalent: ""
        ).target = self
    }

    @objc private func newWindow(_ sender: Any?) {
        onNewWindow()
    }

    @objc private func open(_ sender: Any?) {
        onOpen()
    }

    @objc private func openRecentWorkspace(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onOpenRecentWorkspace(url)
    }

    @objc private func openRecentPDF(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onOpenRecentPDF(url)
    }

    @objc private func clearRecentLocations(_ sender: Any?) {
        recentLocations.clear()
    }

    private func appendRecentSection(
        title: String,
        urls: [URL],
        action: Selector,
        to menu: NSMenu
    ) {
        let header = menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
        header.isEnabled = false

        if urls.isEmpty {
            let emptyItem = menu.addItem(withTitle: "None", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            return
        }

        for url in urls {
            let item = menu.addItem(
                withTitle: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                action: action,
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = url
        }
    }
}
