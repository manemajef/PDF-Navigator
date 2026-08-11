import AppKit
import UniformTypeIdentifiers

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isShowingOpenPanel = false
    private let recentLocations = RecentLocationsStore.shared
    private var launchPanelController: LaunchPanelController?
    private var hasFinishedLaunching = false
    private var isRestoringWindows = true

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
        onShowLaunchPanel: { [weak self] in
            self?.showLaunchPanel()
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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Window restoration can finish before *or* after
        // `applicationDidFinishLaunching`, and it is posted even when there was
        // nothing to restore, so the observer has to be in place beforehand.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowRestorationDidFinish),
            name: NSApplication.didFinishRestoringWindowsNotification,
            object: nil
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        mainMenu.install()
        NSApp.activate(ignoringOtherApps: true)

        hasFinishedLaunching = true
        presentInitialInterfaceIfNeeded()
    }

    @objc private func windowRestorationDidFinish() {
        isRestoringWindows = false
        presentInitialInterfaceIfNeeded()
    }

    /// Runs once, after both launching and restoration are done. The extra hop
    /// lets a launch-time open request (double-clicked file) land first.
    private func presentInitialInterfaceIfNeeded() {
        guard hasFinishedLaunching, !isRestoringWindows else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !hasWorkspaceWindows else { return }
            showInitialWindowOrLaunchPanel()
        }
    }

    private var hasWorkspaceWindows: Bool {
        NSApp.windows.contains { $0.windowController is WindowController }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openLocation(at: url)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        showInitialWindowOrLaunchPanel()
        return true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        if !hasVisibleWindows {
            showInitialWindowOrLaunchPanel()
            return false
        }
        return true
    }

    private func showInitialWindowOrLaunchPanel() {
        #if DEBUG
        if FileManager.default.fileExists(atPath: DevelopmentConfiguration.demoPDFURL.path) {
            openWindow(.pdf(DevelopmentConfiguration.demoPDFURL))
        } else if FileManager.default.fileExists(atPath: DevelopmentConfiguration.demoDirURL.path) {
            openWindow(.folder(DevelopmentConfiguration.demoDirURL))
        } else {
            showLaunchPanel()
        }
        #else
        showLaunchPanel()
        #endif
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

    @discardableResult
    private func openWindow(
        _ request: OpenRequest,
        tabbedWith sourceWindow: NSWindow? = nil,
        activation: TabActivation = .foreground
    ) -> WindowController? {
        launchPanelController?.close()
        let document = WorkspaceDocument(request: request)
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()

        guard let controller = document.windowControllers.first as? WindowController else {
            return nil
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

        return controller
    }

    func configure(_ controller: WindowController) {
        let routing = controller.routing

        routing.newTab = { [weak self, weak controller] activation in
            guard let controller, let sourceWindow = controller.window else { return }
            self?.openWindow(
                .startPage(in: controller.session.root),
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
