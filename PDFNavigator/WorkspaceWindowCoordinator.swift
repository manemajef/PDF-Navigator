import AppKit
import Combine
import SwiftUI

struct WorkspaceLaunchContext: Codable, Hashable {
    let id: UUID
    let workspaceURL: URL?
    let selectedPDF: URL?
    let lastSelectedPDF: URL?
    let presentsWorkspacePicker: Bool?
    let startsAtWelcome: Bool?

    static func newWorkspaceTab(
        workspaceURL: URL?,
        lastSelectedPDF: URL?
    ) -> WorkspaceLaunchContext {
        WorkspaceLaunchContext(
            id: UUID(),
            workspaceURL: workspaceURL,
            selectedPDF: nil,
            lastSelectedPDF: lastSelectedPDF,
            presentsWorkspacePicker: false,
            startsAtWelcome: true
        )
    }

    static func duplicateTab(
        workspaceURL: URL,
        selectedPDF: URL
    ) -> WorkspaceLaunchContext {
        WorkspaceLaunchContext(
            id: UUID(),
            workspaceURL: workspaceURL,
            selectedPDF: selectedPDF,
            lastSelectedPDF: nil,
            presentsWorkspacePicker: false,
            startsAtWelcome: false
        )
    }
}

@MainActor
final class WorkspaceWindowCoordinator: ObservableObject {
    @Published private(set) var window: NSWindow?
    @Published private(set) var isToolbarVisible = true
    @Published private(set) var isInTabGroup = false

    private let launchContextID: UUID?
    private var didAttachToSourceWindow = false
    private var toolbarVisibilityObservation: AnyCancellable?
    private var tabGroupObservation: AnyCancellable?
    private let tabCommandResponder =
        WorkspaceTabCommandResponder()
    private weak var originalNextResponder: NSResponder?

    init(launchContextID: UUID?) {
        self.launchContextID = launchContextID
    }

    var hasWindow: Bool {
        window != nil
    }

    func registerAsTabSource(for contextID: UUID) -> Bool {
        guard let window else {
            return false
        }

        WorkspaceTabRegistry.shared.register(
            source: window,
            for: contextID
        )
        return true
    }

    func resolve(
        _ window: NSWindow,
        onCreateWorkspaceTab: @escaping () -> Void
    ) {
        if self.window !== window {
            self.window = window
        }

        observeToolbarVisibility(in: window)
        installTabCommandResponder(
            in: window,
            onCreateWorkspaceTab: onCreateWorkspaceTab
        )

        guard
            !didAttachToSourceWindow,
            let launchContextID,
            let sourceWindow =
                WorkspaceTabRegistry.shared.takeSource(
                    for: launchContextID
                ),
            sourceWindow !== window
        else {
            observeTabGroup(in: window)
            return
        }

        didAttachToSourceWindow = true
        sourceWindow.addTabbedWindow(window, ordered: .above)
        observeTabGroup(in: window)
        window.makeKeyAndOrderFront(nil)
    }

    private func installTabCommandResponder(
        in window: NSWindow,
        onCreateWorkspaceTab: @escaping () -> Void
    ) {
        tabCommandResponder.onCreateWorkspaceTab =
            onCreateWorkspaceTab

        guard window.nextResponder !== tabCommandResponder else {
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
        guard let tabGroup = window.tabGroup else {
            tabGroupObservation = nil
            isInTabGroup = false
            return
        }

        isInTabGroup = tabGroup.windows.count > 1

        tabGroupObservation = tabGroup.publisher(
            for: \.windows,
            options: [.initial, .new]
        )
        .sink { [weak self] windows in
            self?.isInTabGroup = windows.count > 1
        }
    }
}

@MainActor
private final class WorkspaceTabRegistry {
    static let shared = WorkspaceTabRegistry()

    private var sources: [UUID: WeakWindow] = [:]

    func register(source: NSWindow, for contextID: UUID) {
        sources[contextID] = WeakWindow(source)
    }

    func takeSource(for contextID: UUID) -> NSWindow? {
        defer {
            sources[contextID] = nil
        }

        return sources[contextID]?.value
    }

    private struct WeakWindow {
        weak var value: NSWindow?

        init(_ value: NSWindow) {
            self.value = value
        }
    }
}

struct WorkspaceWindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> ResolverView {
        ResolverView(onResolve: onResolve)
    }

    func updateNSView(
        _ view: ResolverView,
        context: Context
    ) {
        view.onResolve = onResolve
        view.resolveWindow()
    }

    final class ResolverView: NSView {
        var onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        func resolveWindow() {
            if let window {
                onResolve(window)
            }
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
