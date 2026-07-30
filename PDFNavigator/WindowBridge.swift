import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowBridge: ObservableObject {
    @Published private(set) var window: NSWindow?

    private static var tabSources: [UUID: TabSource] = [:]

    private var tabSource: TabSource?

    init(launchID: UUID?) {
        tabSource = launchID.flatMap {
            Self.tabSources.removeValue(forKey: $0)
        }
    }

    var hasWindow: Bool { window != nil }

    var inheritedShellState: WorkspaceShellState? {
        tabSource?.shellState
    }

    func represent(_ url: URL?) {
        guard let window else { return }
        window.representedURL = url
        window.tab.attributedTitle = nil
        window.tab.title = url?.lastPathComponent
    }

    func setToolbarVisible(_ isVisible: Bool) {
        guard let window else { return }
        if let toolbar = window.toolbar {
            toolbar.isVisible = isVisible
            return
        }

        Task { @MainActor [weak window] in
            await Task.yield()
            window?.toolbar?.isVisible = isVisible
        }
    }

    func registerAsTabSource(
        for id: UUID,
        shellState: WorkspaceShellState
    ) -> Bool {
        guard let window else { return false }
        Self.tabSources[id] = TabSource(
            window: window,
            shellState: shellState
        )
        return true
    }

    func resolve(_ window: NSWindow) {
        if let resolvedWindow = self.window {
            assert(resolvedWindow === window)
            guard resolvedWindow === window else { return }
        } else {
            self.window = window
            window.makeFirstResponder(nil)
        }

        if let source = tabSource {
            tabSource = nil
            guard let sourceWindow = source.window,
                  sourceWindow !== window else {
                return
            }
            sourceWindow.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> ResolverView {
        ResolverView(onResolve: onResolve)
    }

    func updateNSView(_ view: ResolverView, context: Context) {
        view.onResolve = onResolve
        view.resolveAfterUpdate()
    }

    final class ResolverView: NSView {
        var onResolve: (NSWindow) -> Void
        private var resolutionScheduled = false

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
            resolveAfterUpdate()
        }

        override func layout() {
            super.layout()
            resolveAfterUpdate()
        }

        func resolveAfterUpdate() {
            guard !resolutionScheduled else { return }
            resolutionScheduled = true

            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self else { return }
                resolutionScheduled = false
                resolve()
            }
        }

        private func resolve() {
            if let window { onResolve(window) }
        }
    }
}

private struct TabSource {
    weak var window: NSWindow?
    let shellState: WorkspaceShellState
}
