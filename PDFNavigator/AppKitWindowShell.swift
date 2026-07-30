import AppKit
import SwiftUI

enum WindowShellSelection: Equatable {
    case swiftUI
    case appKitExperiment

    static let current: Self = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--appkit-window-shell")
            ? .appKitExperiment
            : .swiftUI
        #else
        .swiftUI
        #endif
    }()

    var launchBehavior: SceneLaunchBehavior {
        switch self {
        case .swiftUI:
            .automatic
        case .appKitExperiment:
            .suppressed
        }
    }
}

@MainActor
final class AppKitWindowShell: NSObject, NSApplicationDelegate,
    NSWindowDelegate
{
    private var controllers: [ObjectIdentifier: NSWindowController] = [:]
    private var pendingTabs: [ObjectIdentifier: PendingTab] = [:]

    var workspaceOpener: ((WorkspaceLaunch) -> Void)? {
        guard WindowShellSelection.current == .appKitExperiment else {
            return nil
        }
        return { [weak self] launch in
            self?.openWorkspace(launch)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard WindowShellSelection.current == .appKitExperiment else { return }
        makeWindow(for: .emptyWindow)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        guard WindowShellSelection.current == .appKitExperiment else {
            return true
        }
        if !hasVisibleWindows && controllers.isEmpty {
            makeWindow(for: .emptyWindow)
            return false
        }
        return true
    }

    func openWorkspace(_ launch: WorkspaceLaunch) {
        makeWindow(for: launch)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let id = ObjectIdentifier(window)
        controllers[id] = nil
        pendingTabs[id] = nil
    }

    private func makeWindow(
        for launch: WorkspaceLaunch,
        shellState: WorkspaceShellState? = nil,
        tabbedWith sourceWindow: NSWindow? = nil
    ) {
        let rootView = WorkspaceView(
            restoration: .constant(launch),
            initialPDF: launch.selectedPDF,
            initialWorkspace: launch.rootURL,
            lastSelectedPDF: launch.lastSelectedPDF,
            initialShellState: shellState ?? WorkspaceShellState(),
            presentsPicker: launch.presentsPicker,
            startsAtWelcome: launch.startsAtWelcome,
            openTabWithAppKit: {
                [weak self] launch, shellState, sourceWindow in
                self?.makeWindow(
                    for: launch,
                    shellState: shellState,
                    tabbedWith: sourceWindow
                )
            },
            onWindowReady: { [weak self] window in
                self?.attachPendingTab(for: window)
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sceneBridgingOptions = .all

        let window = NSWindow(contentViewController: hostingController)
        window.isRestorable = false
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 700, height: 850))
        window.delegate = self

        let id = ObjectIdentifier(window)
        controllers[id] = NSWindowController(window: window)

        if let sourceWindow {
            pendingTabs[id] = PendingTab(
                sourceWindow: sourceWindow
            )
        } else {
            window.center()
        }

        controllers[id]?.showWindow(nil)
        if sourceWindow == nil {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func attachPendingTab(for window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard let pendingTab = pendingTabs.removeValue(forKey: id),
              let sourceWindow = pendingTab.sourceWindow,
              sourceWindow !== window else {
            return
        }

        sourceWindow.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct PendingTab {
    weak var sourceWindow: NSWindow?
}
