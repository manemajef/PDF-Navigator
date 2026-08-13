import AppKit

/// Builds the window's toolbars from `ToolbarCatalogue` and renders
/// `ToolbarState` onto whichever one is installed. Stores no application state.
///
/// One toolbar, installed once and never replaced. A mode change rewrites its
/// contents rather than exchanging the toolbar, which is what keeps the
/// titlebar from crossfading; the arrangement each mode is left in survives in
/// `ToolbarArrangements`.
///
/// Enabled state is not part of the render pass. Top-level items self-validate
/// through `WindowController.canPerform(_:)`, which AppKit calls before
/// displaying them. This type renders only what validation has no hook for:
/// the subitem and selection state of groups.
final class ToolbarController: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
    private weak var target: WindowController?
    private weak var window: NSWindow?

    /// This window's toolbar, told apart from the palette's own by the
    /// identifier it was built with.
    ///
    /// Unique per window, and never persisted — which is why it is minted here
    /// rather than named in the catalogue. AppKit keeps toolbars that share an
    /// identifier at the same item order, live: setting `itemIdentifiers` on
    /// one rewrites every other, and a window opened later inherits the result.
    /// Two windows in different modes hold different orders, so they cannot
    /// share. What the *user* arranges is still shared, through
    /// `ToolbarArrangements`, which each window reads on its next mode change.
    private let identifier = NSToolbar.Identifier(
        "WorkspaceToolbar.\(UUID().uuidString)"
    )

    /// The mode whose arrangement is on the toolbar, or `nil` until the first
    /// render puts one there.
    private var appliedMode: ToolbarMode?

    /// The toolbar on the window. Read from the window rather than cached, so
    /// it cannot disagree with what is on screen.
    private var toolbar: NSToolbar? { window?.toolbar }

    init(target: WindowController) {
        self.target = target
    }

    // MARK: - Installing

    /// Puts the toolbar on `window`, once.
    ///
    /// The comparison is what makes this safe to call more than once. Assigning
    /// a second toolbar is what this design exists to avoid: AppKit rebuilds
    /// the titlebar's toolbar view for a new one and crossfades the exchange.
    func install(in window: NSWindow) {
        self.window = window
        guard window.toolbar?.identifier != identifier else { return }

        #if DEBUG
        ToolbarCatalogue.validate()
        #endif

        let toolbar = NSToolbar(identifier: identifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        // Deliberately not autosaving: one saved arrangement per identifier
        // cannot hold two modes, and the identifier above is per window anyway.
        window.toolbar = toolbar
    }

    // MARK: - Arrangements

    /// Swaps the toolbar's contents to `mode`'s arrangement, keeping whatever
    /// the user made of the one being left.
    ///
    /// `itemIdentifiers` diffs against what is already there, so the items in
    /// both arrangements stay put and only the difference animates.
    private func apply(_ mode: ToolbarMode) {
        guard let toolbar, appliedMode != mode else { return }

        captureArrangement()
        appliedMode = mode
        toolbar.itemIdentifiers = ToolbarArrangements.shared.arrangement(for: mode)
    }

    /// Records what the toolbar currently holds as the arrangement for the mode
    /// it is showing.
    ///
    /// The window calls this on every pass of the event loop, because AppKit
    /// posts nothing when the customization palette closes and an arrangement
    /// made there is otherwise lost at the next mode change. Unchanged lists
    /// are not written.
    func captureArrangement() {
        guard let toolbar, let appliedMode else { return }
        ToolbarArrangements.shared.setArrangement(
            toolbar.itemIdentifiers,
            for: appliedMode
        )
    }

    // MARK: - Rendering

    /// Makes the toolbar match `state`. Safe to call as often as needed: every
    /// write below is either cheap and idempotent or guarded by a comparison.
    func render(_ state: ToolbarState) {
        apply(state.mode)
        guard let toolbar else { return }

        for item in toolbar.items {
            if let group = item as? NSToolbarItemGroup,
               let spec = ToolbarCatalogue.groups[item.itemIdentifier] {
                group.render(spec, in: state, target: target)
            }
        }

        // Prompts AppKit to re-ask `canPerform(_:)` for everything on screen,
        // which is what actually updates enabled state.
        toolbar.validateVisibleItems()
    }

    /// A command, not part of `render(_:)`: clearing the field is an effect of
    /// changing document. Folding it into render would wipe whatever the user
    /// had typed on every unrelated change.
    func resetSearch() {
        searchItem?.endSearchInteraction()
        searchItem?.searchField.stringValue = ""
    }

    func beginSearch() {
        searchItem?.beginSearchInteraction()
    }

    func endSearch() {
        searchItem?.endSearchInteraction()
    }

    private var searchItem: NSSearchToolbarItem? {
        toolbar?.items.first { $0.itemIdentifier == .workspaceSearch }
            as? NSSearchToolbarItem
    }

    // MARK: - NSToolbarDelegate

    /// Every item, in both modes: the palette is a place to find tools, and one
    /// that offered only the current mode's would hide half of them behind a
    /// mode change. Which of them a mode *starts* with is `defaults`, below.
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbar.identifier == identifier ? ToolbarCatalogue.allIdentifiers : []
    }

    /// Answers for the mode on screen, so Restore Defaults restores the
    /// arrangement that mode began with rather than a union of both.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        guard toolbar.identifier == identifier else { return [] }
        return ToolbarCatalogue.defaultIdentifiers(for: appliedMode ?? .browsing)
    }

    /// The sidebar toggle is supplied by AppKit, so it is relabelled on
    /// arrival.
    func toolbarWillAddItem(_ notification: Notification) {
        guard
            let item = notification.userInfo?[NSToolbarUserInfoKey.itemKey] as? NSToolbarItem,
            item.itemIdentifier == .toggleSidebar
        else { return }

        item.configure(
            label: "Navigator",
            toolTip: "Toggle Navigator",
            target: target,
            action: #selector(WindowController.toggleSidebar(_:))
        )
    }

    /// Builds an item from the catalogue. Items start in their default state
    /// and are corrected by the next `render(_:)`.
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if let spec = ToolbarCatalogue.items[identifier] {
            return NSToolbarItem(
                identifier: identifier,
                label: spec.label,
                symbolName: spec.symbol,
                target: target,
                action: spec.action
            )
        }

        if let spec = ToolbarCatalogue.groups[identifier] {
            return NSToolbarItemGroup.make(identifier: identifier, spec: spec)
        }

        if identifier == .workspaceSearch {
            return NSSearchToolbarItem(
                identifier: identifier,
                label: "Search",
                placeholder: "Search",
                target: target,
                action: #selector(WindowController.searchFieldSubmitted(_:)),
                delegate: self
            )
        }

        return nil
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        guard let searchField = notification.object as? NSSearchField else { return }
        target?.searchFieldChanged(searchField)
    }
}

// MARK: - Item construction

private extension NSToolbarItem {
    convenience init(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        target: AnyObject?,
        action: Selector
    ) {
        self.init(itemIdentifier: identifier)
        configure(label: label, target: target, action: action)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
    }

    func configure(
        label: String,
        toolTip: String? = nil,
        target: AnyObject?,
        action: Selector?
    ) {
        self.label = label
        paletteLabel = label
        self.toolTip = toolTip ?? label
        self.target = target
        self.action = action
    }
}

private extension NSSearchToolbarItem {
    convenience init(
        identifier: NSToolbarItem.Identifier,
        label: String,
        placeholder: String,
        target: AnyObject?,
        action: Selector,
        delegate: NSSearchFieldDelegate?
    ) {
        self.init(itemIdentifier: identifier)
        self.label = label
        paletteLabel = label
        searchField.placeholderString = placeholder
        searchField.delegate = delegate
        searchField.target = target
        searchField.action = action
    }
}

private extension NSToolbarItemGroup {
    static func make(
        identifier: NSToolbarItem.Identifier,
        spec: ToolbarCatalogue.Group
    ) -> NSToolbarItemGroup? {
        let images = spec.subitems.compactMap {
            NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.tooltip)
        }
        guard images.count == spec.subitems.count else { return nil }

        let group = NSToolbarItemGroup(
            itemIdentifier: identifier,
            images: images,
            selectionMode: spec.selectedIndex == nil ? .momentary : .selectAny,
            labels: spec.subitems.map(\.tooltip),
            target: nil,
            action: nil
        )
        group.label = spec.label
        group.paletteLabel = spec.label
        group.isNavigational = spec.isNavigational
        group.controlRepresentation = .expanded
        return group
    }

    /// AppKit validates a group as a single unit, which cannot express "back is
    /// available but forward is not". Turning `autovalidates` off and setting
    /// each subitem here is what buys per-segment availability.
    func render(
        _ spec: ToolbarCatalogue.Group,
        in state: ToolbarState,
        target: AnyObject?
    ) {
//        let isAvailable = !spec.requiresPDF || state.hasPDF

        for (subitem, subspec) in zip(subitems, spec.subitems) {
            subitem.target = target
            subitem.action = subspec.action
            subitem.toolTip = subspec.tooltip
            subitem.autovalidates = false
//            subitem.isEnabled = isAvailable && subspec.isEnabled(state)
            subitem.isEnabled = subspec.isEnabled(state)
        }

        let selection = spec.selectedIndex?(state) ?? ToolbarCatalogue.noSelection
        selectedIndex = selection
        for index in subitems.indices {
            setSelected(index == selection, at: index)
        }
    }
}
