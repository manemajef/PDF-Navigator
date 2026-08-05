import AppKit
import UniformTypeIdentifiers

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isShowingOpenPanel = false
    private let recentLocations = RecentLocationsStore.shared
    private var launchPanelController: LaunchPanelController?

    private lazy var mainMenu = MainMenu(
        recentLocations: recentLocations,
        onNewWindow: { [weak self] in
            guard let self, let request = promptForOpenRequest() else { return }
            openWindow(request)
        },
        onOpen: { [weak self] in
            guard let self, let request = promptForOpenRequest() else { return }
            open(request, replacing: activeWindowController)
        },
        onOpenRecentWorkspace: { [weak self] url in
            self?.openWindow(.folder(url))
        },
        onOpenRecentPDF: { [weak self] url in
            self?.openWindow(.pdf(url))
        }
    )

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        mainMenu.install()
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openLocation(at: url)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        #if DEBUG
        openWindow(.pdf(DevelopmentConfiguration.demoPDFURL))
        #else
        showLaunchPanel()
        #endif
        return true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        if !hasVisibleWindows {
            #if DEBUG
            openWindow(.pdf(DevelopmentConfiguration.demoPDFURL))
            #else
            showLaunchPanel()
            #endif
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

    private func showLaunchPanel() {
        if launchPanelController == nil {
            let controller = LaunchPanelController()
            controller.onOpen = { [weak self] in
                guard let self, let request = promptForOpenRequest() else { return }
                openWindow(request)
            }
            controller.onSelectWorkspace = { [weak self] url in
                self?.openWindow(.folder(url))
            }
            controller.onSelectPDF = { [weak self] url in
                self?.openWindow(.pdf(url))
            }
            launchPanelController = controller
        }
        launchPanelController?.refresh()
        launchPanelController?.showWindow(nil)
    }

    private func promptForOpenRequest() -> OpenRequest? {
        guard !isShowingOpenPanel else { return nil }
        isShowingOpenPanel = true
        defer { isShowingOpenPanel = false }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf, .folder]
        panel.message = "Choose a PDF or folder"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return request(for: url)
    }

    private func openLocation(at url: URL) {
        open(request(for: url), replacing: activeWindowController)
    }

    private func request(for url: URL) -> OpenRequest {
        let standardizedURL = url.standardizedFileURL
        if standardizedURL.isExistingDirectory {
            return .folder(standardizedURL)
        } else {
            return .pdf(standardizedURL)
        }
    }

    private func open(
        _ request: OpenRequest,
        replacing controller: WindowController?
    ) {
        if let document = controller?.document as? WorkspaceDocument {
            document.open(request)
        } else {
            openWindow(request)
        }
    }

    private var activeWindowController: WindowController? {
        NSApp.keyWindow?.windowController as? WindowController
    }

    private func openWindow(
        _ request: OpenRequest,
        tabbedWith sourceWindow: NSWindow? = nil,
        activation: TabActivation = .foreground
    ) {
        launchPanelController?.close()
        let document = WorkspaceDocument(request: request)
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()

        guard let controller = document.windowControllers.first as? WindowController else {
            return
        }

        if let sourceWindow, let tabWindow = controller.window {
            sourceWindow.addTabbedWindow(tabWindow, ordered: .above)
            switch activation {
            case .foreground:
                tabWindow.makeKeyAndOrderFront(nil)
            case .background:
                sourceWindow.tabGroup?.selectedWindow = sourceWindow
                sourceWindow.makeKeyAndOrderFront(nil)
            }
        } else {
            document.showWindows()
        }

        DispatchQueue.main.async { [weak controller] in
            controller?.endSearchInteraction()
        }
    }

    func configure(_ controller: WindowController) {
        let routing = controller.routing

        routing.newTab = { [weak self, weak controller] activation in
            guard let controller, let sourceWindow = controller.window else { return }
            self?.openWindow(
                .folder(controller.session.root),
                tabbedWith: sourceWindow,
                activation: activation
            )
        }
        routing.openInNewTab = { [weak self, weak controller] url, activation in
            guard let controller, let sourceWindow = controller.window else { return }
            self?.openWindow(
                .pdf(url, in: controller.session.root),
                tabbedWith: sourceWindow,
                activation: activation
            )
        }
        routing.chooseLocation = { [weak self, weak controller] in
            guard let self, let request = promptForOpenRequest() else { return }
            open(request, replacing: controller)
        }
    }
}

private extension URL {
    var isExistingDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
