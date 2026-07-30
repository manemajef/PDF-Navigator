import AppKit
import UniformTypeIdentifiers

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isPromptingForWorkspace = false
    private var windowControllers: [ObjectIdentifier: WorkspaceWindowController] = [:]
    private let recentLocations = RecentLocationsStore.shared

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()
        NSApp.activate(ignoringOtherApps: true)
        openWorkspaceWindow(.empty)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openWorkspace(at: url)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        openWorkspaceWindow(.empty)
        return true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        if !hasVisibleWindows {
            openWorkspaceWindow(.empty)
            return false
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc private func openDocument(_ sender: Any?) {
        promptForWorkspaceIfNeeded()
    }

    @objc private func newDocument(_ sender: Any?) {
        openWorkspaceWindow(.empty)
    }

    private func promptForWorkspaceIfNeeded() {
        guard !isPromptingForWorkspace else { return }
        isPromptingForWorkspace = true
        defer { isPromptingForWorkspace = false }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf, .folder]
        panel.message = "Choose a PDF or folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWorkspace(at: url)
    }

    private func openWorkspace(at url: URL) {
        let url = url.standardizedFileURL
        if url.isExistingDirectory {
            openWorkspaceWindow(.folder(url))
        } else {
            openWorkspaceWindow(.pdf(url))
        }
    }

    private func openWorkspaceWindow(
        _ request: WorkspaceOpenRequest,
        tabbedWith sourceWindow: NSWindow? = nil
    ) {
        let controller = WorkspaceWindowController()
        let identifier = ObjectIdentifier(controller)
        windowControllers[identifier] = controller
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windowControllers[ObjectIdentifier(controller)] = nil
        }
        controller.openWorkspaceInNewTab = { [weak self, weak controller] request in
            guard let sourceWindow = controller?.window else { return }
            self?.openWorkspaceWindow(request, tabbedWith: sourceWindow)
        }
        controller.onSelectedPDF = { [weak self] url in
            self?.recentLocations.notePDF(url)
        }
        controller.display(
            workspaceRootURL: request.workspaceRootURL,
            selectedPDFURL: request.selectedPDFURL
        )
        noteRecentLocations(for: request)

        if let sourceWindow, let tabWindow = controller.window {
            sourceWindow.addTabbedWindow(tabWindow, ordered: .above)
            tabWindow.makeKeyAndOrderFront(nil)
        }
    }

    private func noteRecentLocations(for request: WorkspaceOpenRequest) {
        if let workspaceRootURL = request.workspaceRootURL {
            recentLocations.noteWorkspace(workspaceRootURL)
        }
        if let selectedPDFURL = request.selectedPDFURL {
            recentLocations.notePDF(selectedPDFURL)
        }
    }

    private func installMainMenu() {
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
            action: #selector(newDocument(_:)),
            keyEquivalent: "n"
        ).target = self
        fileMenu.addItem(
            withTitle: "New Tab",
            action: #selector(WorkspaceWindowController.newWorkspaceTab(_:)),
            keyEquivalent: "t"
        )
        fileMenu.addItem(
            withTitle: "Open...",
            action: #selector(openDocument(_:)),
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
            action: #selector(WorkspaceWindowController.toggleSidebar(_:)),
            keyEquivalent: "s"
        ).keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(
            withTitle: "Toggle Toolbar",
            action: #selector(NSWindow.toggleToolbarShown(_:)),
            keyEquivalent: "t"
        ).keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            withTitle: "Actual Size",
            action: #selector(WorkspaceWindowController.showActualSize(_:)),
            keyEquivalent: "0"
        )
        viewMenu.addItem(
            withTitle: "Zoom to Fit",
            action: #selector(WorkspaceWindowController.zoomToFit(_:)),
            keyEquivalent: "9"
        )
        viewMenu.addItem(
            withTitle: "Zoom In",
            action: #selector(WorkspaceWindowController.zoomIn(_:)),
            keyEquivalent: "="
        )
        viewMenu.addItem(
            withTitle: "Zoom Out",
            action: #selector(WorkspaceWindowController.zoomOut(_:)),
            keyEquivalent: "-"
        )

        let navigateMenuItem = NSMenuItem()
        mainMenu.addItem(navigateMenuItem)
        let navigateMenu = NSMenu(title: "Navigate")
        navigateMenuItem.submenu = navigateMenu
        navigateMenu.addItem(
            withTitle: "Back",
            action: #selector(WorkspaceWindowController.goBack(_:)),
            keyEquivalent: "["
        )
        navigateMenu.addItem(
            withTitle: "Forward",
            action: #selector(WorkspaceWindowController.goForward(_:)),
            keyEquivalent: "]"
        )
        navigateMenu.addItem(.separator())
        navigateMenu.addItem(
            withTitle: "Previous Page",
            action: #selector(WorkspaceWindowController.goToPreviousPage(_:)),
            keyEquivalent: ""
        )
        navigateMenu.addItem(
            withTitle: "Next Page",
            action: #selector(WorkspaceWindowController.goToNextPage(_:)),
            keyEquivalent: ""
        )

        let findMenuItem = NSMenuItem()
        mainMenu.addItem(findMenuItem)
        let findMenu = NSMenu(title: "Find")
        findMenuItem.submenu = findMenu
        findMenu.addItem(
            withTitle: "Find...",
            action: #selector(WorkspaceWindowController.beginSearch(_:)),
            keyEquivalent: "f"
        )
        findMenu.addItem(
            withTitle: "Find Next",
            action: #selector(WorkspaceWindowController.selectNextSearchMatch(_:)),
            keyEquivalent: "g"
        )
        let previousMatchItem = findMenu.addItem(
            withTitle: "Find Previous",
            action: #selector(WorkspaceWindowController.selectPreviousSearchMatch(_:)),
            keyEquivalent: "g"
        )
        previousMatchItem.keyEquivalentModifierMask = [.command, .shift]

        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Open in Default App",
            action: #selector(WorkspaceWindowController.openCurrentPDFInDefaultApp(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: "Share...",
            action: #selector(WorkspaceWindowController.shareCurrentPDF(_:)),
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

    @objc private func openRecentWorkspace(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        openWorkspaceWindow(.folder(url))
    }

    @objc private func openRecentPDF(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        openWorkspaceWindow(.pdf(url))
    }

    @objc private func clearRecentLocations(_ sender: Any?) {
        recentLocations.clear()
    }
}

extension AppDelegate: NSMenuDelegate {
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

private extension URL {
    var isExistingDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

#if DEBUG
enum DevelopmentConfiguration {
    static let demoPDFURL = repositoryRoot
        .appendingPathComponent("DEMO_DIR", isDirectory: true)
        .appendingPathComponent("micro3-sylabus.pdf", isDirectory: false)

    private static let repositoryRoot = URL(
        fileURLWithPath: #filePath
    )
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}
#endif
