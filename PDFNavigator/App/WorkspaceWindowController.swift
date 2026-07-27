import AppKit
import Combine

@MainActor
final class WorkspaceWindowController: ObservableObject {
    @Published private(set) var window: NSWindow?
    @Published private(set) var isToolbarVisible = true

    private let sourceWindowNumber: Int?
    private var didAttachToSourceWindow = false
    private var toolbarVisibilityObservation:
        AnyCancellable?
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
        observeToolbarVisibility(in: window)
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
}

@MainActor
private final class WorkspaceTabCommandResponder:
    NSResponder {
    var onCreateWorkspaceTab: () -> Void = {}

    override func newWindowForTab(_ sender: Any?) {
        onCreateWorkspaceTab()
    }
}
