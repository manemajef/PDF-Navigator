import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowBridge: ObservableObject {
    @Published private(set) var window: NSWindow?
    @Published private(set) var isToolbarVisible = true
    @Published private(set) var isInTabGroup = false

    private static var tabSources: [UUID: TabSource] = [:]

    private let launchID: UUID?
    private let tabResponder = TabResponder()
    private var didJoinSource = false
    private var toolbarObservation: AnyCancellable?
    private var tabObservation: AnyCancellable?
    private weak var observedTabGroup: NSWindowTabGroup?

    init(launchID: UUID?) {
        self.launchID = launchID
    }

    var hasWindow: Bool { window != nil }

    func toggleToolbar() {
        isToolbarVisible.toggle()
        applyToolbarVisibility()
    }

    func represent(_ url: URL?, fallbackTitle: String) {
        guard let window else { return }
        Task { @MainActor [weak window] in
            await Task.yield()
            window?.representedURL = url
            window?.title = url?.lastPathComponent ?? fallbackTitle
        }
    }

    func registerAsTabSource(for id: UUID) -> Bool {
        guard let window else { return false }
        Self.tabSources[id] = TabSource(
            window: window,
            isToolbarVisible: isToolbarVisible
        )
        return true
    }

    func resolve(_ window: NSWindow, onNewTab: @escaping () -> Void) {
        if self.window !== window {
            self.window = window
            isToolbarVisible = window.toolbar?.isVisible ?? true
            window.makeFirstResponder(nil)
            toolbarObservation = nil
            tabObservation = nil
            observedTabGroup = nil
            observeToolbar(in: window)
        }

        installTabResponder(in: window, action: onNewTab)

        if !didJoinSource,
           let launchID,
           let source = Self.takeSource(for: launchID),
           let sourceWindow = source.window,
           sourceWindow !== window {
            didJoinSource = true
            isToolbarVisible = source.isToolbarVisible
            sourceWindow.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        }

        observeTabs(in: window)
        applyToolbarVisibility()
    }

    private static func takeSource(for id: UUID) -> TabSource? {
        defer { tabSources[id] = nil }
        return tabSources[id]
    }

    private func observeToolbar(in window: NSWindow) {
        guard toolbarObservation == nil, let toolbar = window.toolbar else { return }
        toolbarObservation = toolbar.publisher(
            for: \.isVisible,
            options: [.initial, .new]
        )
        .sink { [weak self] _ in
            self?.applyToolbarAppearance()
        }
    }

    private func applyToolbarAppearance() {
        guard let window else { return }
        let isToolbarVisible = window.toolbar?.isVisible != false
        window.titlebarSeparatorStyle = isToolbarVisible ? .automatic : .none
        window.titlebarAppearsTransparent = !isToolbarVisible && !isInTabGroup
    }

    private func applyToolbarVisibility() {
        guard let toolbar = window?.toolbar else { return }
        if toolbar.isVisible != isToolbarVisible {
            toolbar.isVisible = isToolbarVisible
        }
        applyToolbarAppearance()
    }

    private func observeTabs(in window: NSWindow) {
        guard let tabGroup = window.tabGroup else {
            observedTabGroup = nil
            tabObservation = nil
            if isInTabGroup {
                isInTabGroup = false
            }
            applyToolbarAppearance()
            return
        }

        guard observedTabGroup !== tabGroup else { return }
        observedTabGroup = tabGroup
        tabObservation = tabGroup.publisher(
            for: \.windows,
            options: [.initial, .new]
        )
        .sink { [weak self] windows in
            let isInTabGroup = windows.count > 1
            if self?.isInTabGroup != isInTabGroup {
                self?.isInTabGroup = isInTabGroup
            }
            self?.applyToolbarAppearance()
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
    let isToolbarVisible: Bool

    init(window: NSWindow, isToolbarVisible: Bool) {
        self.window = window
        self.isToolbarVisible = isToolbarVisible
    }
}
