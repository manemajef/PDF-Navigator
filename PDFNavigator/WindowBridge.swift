import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowBridge: ObservableObject {
    @Published private(set) var window: NSWindow?
    @Published private(set) var isNativeTabBarVisible = false

    private static var tabSources: [UUID: TabSource] = [:]

    private let launchID: UUID?
    private let tabResponder = TabResponder()
    private var didJoinSource = false
    private var tabObservation: AnyCancellable?
    private weak var observedTabGroup: NSWindowTabGroup?

    init(launchID: UUID?) {
        self.launchID = launchID
    }

    var hasWindow: Bool { window != nil }

    func toggleToolbar() {
        window?.toolbar?.isVisible.toggle()
    }

    func represent(_ url: URL?) {
        guard let window else { return }
        Task { @MainActor [weak window] in
            await Task.yield()
            window?.representedURL = url
        }
    }

    func registerAsTabSource(for id: UUID) -> Bool {
        guard let window else { return false }
        Self.tabSources[id] = TabSource(
            window: window,
            toolbarIsVisible: window.toolbar?.isVisible ?? true
        )
        return true
    }

    func resolve(_ window: NSWindow, onNewTab: @escaping () -> Void) {
        if self.window !== window {
            self.window = window
            window.makeFirstResponder(nil)
            tabObservation = nil
            observedTabGroup = nil
        }

        installTabResponder(in: window, action: onNewTab)

        if !didJoinSource,
           let launchID,
           let source = Self.takeSource(for: launchID),
           let sourceWindow = source.window,
           sourceWindow !== window {
            didJoinSource = true
            sourceWindow.addTabbedWindow(window, ordered: .above)
            window.toolbar?.isVisible = source.toolbarIsVisible
            window.makeKeyAndOrderFront(nil)
        }

        observeTabGroup(in: window)
        refreshTabBarVisibility(in: window)
    }

    private static func takeSource(for id: UUID) -> TabSource? {
        defer { tabSources[id] = nil }
        return tabSources[id]
    }

    private func observeTabGroup(in window: NSWindow) {
        let tabGroup = window.tabGroup
        guard observedTabGroup !== tabGroup else { return }
        observedTabGroup = tabGroup
        tabObservation = nil

        guard let tabGroup else { return }
        tabObservation = tabGroup.publisher(
            for: \.windows,
            options: [.initial, .new]
        )
        .sink { [weak self, weak window] _ in
            guard let self, let window else { return }
            self.observeTabGroup(in: window)
            self.refreshTabBarVisibility(in: window)
        }
    }

    private func refreshTabBarVisibility(in window: NSWindow) {
        guard self.window === window else { return }
        let isVisible = window.tabbedWindows != nil
        if isNativeTabBarVisible != isVisible {
            isNativeTabBarVisible = isVisible
        }
    }

    private func installTabResponder(
        in window: NSWindow,
        action: @escaping () -> Void
    ) {
        tabResponder.action = action
        guard window.nextResponder !== tabResponder else { return }
        tabResponder.nextResponder = window.nextResponder
        window.nextResponder = tabResponder
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

@MainActor
private final class TabResponder: NSResponder {
    var action: () -> Void = {}

    override func newWindowForTab(_ sender: Any?) {
        action()
    }
}

private struct TabSource {
    weak var window: NSWindow?
    let toolbarIsVisible: Bool

    init(window: NSWindow, toolbarIsVisible: Bool) {
        self.window = window
        self.toolbarIsVisible = toolbarIsVisible
    }
}
