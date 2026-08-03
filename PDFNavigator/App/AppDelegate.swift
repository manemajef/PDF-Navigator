import AppKit
import UniformTypeIdentifiers

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isPromptingForWorkspace = false
    private let recentLocations = RecentLocationsStore.shared
    private lazy var mainMenu = MainMenu(
        recentLocations: recentLocations,
        onNewWindow: { [weak self] in
            self?.openWorkspaceWindow(.empty)
        },
        onOpen: { [weak self] in
            guard let self, let request = promptForWorkspace() else { return }
            open(request, replacing: activeWorkspaceController)
        },
        onOpenRecentWorkspace: { [weak self] url in
            self?.openWorkspaceWindow(.folder(url))
        },
        onOpenRecentPDF: { [weak self] url in
            self?.openWorkspaceWindow(.pdf(url))
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
            openWorkspace(at: url)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        #if DEBUG
        openWorkspaceWindow(.pdf(DevelopmentConfiguration.demoPDFURL))
        #else
        openWorkspaceWindow(.empty)
        #endif

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

    private func promptForWorkspace() -> WorkspaceOpenRequest? {
        guard !isPromptingForWorkspace else { return nil }
        isPromptingForWorkspace = true
        defer { isPromptingForWorkspace = false }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf, .folder]
        panel.message = "Choose a PDF or folder"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return request(for: url)
    }

    private func openWorkspace(at url: URL) {
        open(request(for: url), replacing: activeWorkspaceController)
    }

    private func request(for url: URL) -> WorkspaceOpenRequest {
        let standardizedURL = url.standardizedFileURL
        if standardizedURL.isExistingDirectory {
            return .folder(standardizedURL)
        } else {
            return .pdf(standardizedURL)
        }
    }

    private func open(
        _ request: WorkspaceOpenRequest,
        replacing controller: WorkspaceWindowController?
    ) {
        if let document = controller?.document as? WorkspaceDocument {
            document.open(request)
        } else {
            openWorkspaceWindow(request)
        }
    }

    private var activeWorkspaceController: WorkspaceWindowController? {
        NSApp.keyWindow?.windowController as? WorkspaceWindowController
    }

    private func openWorkspaceWindow(
        _ request: WorkspaceOpenRequest,
        tabbedWith sourceWindow: NSWindow? = nil
    ) {
        let document = WorkspaceDocument(request: request)
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()

        guard let controller = document.windowControllers.first as? WorkspaceWindowController else {
            return
        }

        if let sourceWindow, let tabWindow = controller.window {
            sourceWindow.addTabbedWindow(tabWindow, ordered: .above)
            tabWindow.makeKeyAndOrderFront(nil)
        } else {
            document.showWindows()
        }

        DispatchQueue.main.async { [weak controller] in
            controller?.endSearchInteraction()
        }
    }

    func configure(_ controller: WorkspaceWindowController) {
        let actions = controller.actions

        actions.newTab = { [weak self, weak controller] in
            guard let sourceWindow = controller?.window else { return }
            let request: WorkspaceOpenRequest
            if let root = controller?.session.root {
                request = .folder(root)
            } else {
                request = .empty
            }
            self?.openWorkspaceWindow(request, tabbedWith: sourceWindow)
        }
        actions.openInNewTab = { [weak self, weak controller] url in
            guard let sourceWindow = controller?.window else { return }
            self?.openWorkspaceWindow(.pdf(url), tabbedWith: sourceWindow)
        }
        actions.chooseWorkspace = { [weak self, weak controller] in
            guard let self, let request = promptForWorkspace() else { return }
            open(request, replacing: controller)
        }
        actions.openPDF = { [weak self, weak controller] url in
            self?.open(.pdf(url), replacing: controller)
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
