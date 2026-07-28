import AppKit
import Combine

@MainActor
final class WorkspaceWindowController: ObservableObject {
    @Published private(set) var window: NSWindow?
    @Published private(set) var isToolbarVisible = true
    @Published private(set) var isInTabGroup = false

    private let sourceWindowNumber: Int?
    private var didAttachToSourceWindow = false
    private var toolbarVisibilityObservation:
        AnyCancellable?
    private var tabGroupObservation: AnyCancellable?
    private let tabCommandResponder =
        WorkspaceTabCommandResponder()
    private weak var originalNextResponder: NSResponder?

    init(sourceWindowNumber: Int?) {
        self.sourceWindowNumber = sourceWindowNumber
    }

    var windowNumber: Int? {
        window?.windowNumber
    }

    func resolve(
        _ window: NSWindow,
        onCreateWorkspaceTab: @escaping () -> Void
    ) {
        if self.window !== window {
            self.window = window
        }

        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        observeToolbarVisibility(in: window)
        observeTabGroup(in: window)
        installTabCommandResponder(
            in: window,
            onCreateWorkspaceTab: onCreateWorkspaceTab
        )

        guard
            !didAttachToSourceWindow,
            let sourceWindowNumber,
            let sourceWindow = NSApp.window(
                withWindowNumber: sourceWindowNumber
            ),
            sourceWindow !== window
        else {
            return
        }

        didAttachToSourceWindow = true
        sourceWindow.addTabbedWindow(window, ordered: .above)
        updateTabGroupStatus(for: window)
        window.makeKeyAndOrderFront(nil)
    }

    private func installTabCommandResponder(
        in window: NSWindow,
        onCreateWorkspaceTab: @escaping () -> Void
    ) {
        tabCommandResponder.onCreateWorkspaceTab =
            onCreateWorkspaceTab

        guard window.nextResponder !== tabCommandResponder
        else {
            return
        }

        originalNextResponder = window.nextResponder
        tabCommandResponder.nextResponder =
            originalNextResponder
        window.nextResponder = tabCommandResponder
    }

    private func observeToolbarVisibility(
        in window: NSWindow
    ) {
        guard
            toolbarVisibilityObservation == nil,
            let toolbar = window.toolbar
        else {
            return
        }

        toolbarVisibilityObservation = toolbar.publisher(
            for: \.isVisible,
            options: [.initial, .new]
        )
        .sink { [weak self] isVisible in
            self?.isToolbarVisible = isVisible
        }
    }

    private func observeTabGroup(in window: NSWindow) {
        updateTabGroupStatus(for: window)

        guard tabGroupObservation == nil else {
            return
        }

        tabGroupObservation = NotificationCenter.default
            .publisher(
                for: NSWindow.didBecomeKeyNotification,
                object: window
            )
            .sink { [weak self, weak window] _ in
                guard let self, let window else {
                    return
                }

                self.updateTabGroupStatus(for: window)
            }
    }

    private func updateTabGroupStatus(for window: NSWindow) {
        isInTabGroup = (window.tabbedWindows?.count ?? 0) > 1
    }
}

@MainActor
private final class WorkspaceTabCommandResponder:
    NSResponder {
    var onCreateWorkspaceTab: () -> Void = {}

    override func newWindowForTab(_ sender: Any?) {
        onCreateWorkspaceTab()
    }
}
