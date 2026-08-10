import AppKit

/// Builds the window's toolbar from `ToolbarCatalogue` and renders
/// `ToolbarState` onto it. Stores no application state.
///
/// Enabled state is not part of the render pass. Top-level items self-validate
/// through `WindowController.canPerform(_:)`, which AppKit calls before
/// displaying them. This type renders only what validation has no hook for:
/// visibility, and the subitem and selection state of groups.
final class ToolbarController: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
    private weak var target: WindowController?
    private weak var toolbar: NSToolbar?

    init(target: WindowController) {
        self.target = target
    }

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "WorkspaceToolbarV8")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        #if !DEBUG
        toolbar.autosavesConfiguration = true
        #endif
        self.toolbar = toolbar
        return toolbar
    }

    // MARK: - Rendering

    /// Makes the toolbar match `state`. Safe to call as often as needed: every
    /// write below is either cheap and idempotent or guarded by a comparison.
    func render(_ state: ToolbarState) {
        guard let toolbar else { return }

        for item in toolbar.items {
            if ToolbarCatalogue.pdfOnlyIdentifiers.contains(item.itemIdentifier) {
                setHidden(!state.hasPDF, on: item)
            }
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

    private func setHidden(_ isHidden: Bool, on item: NSToolbarItem) {
        guard item.isHidden != isHidden else { return }
        item.isHidden = isHidden
    }

    private var searchItem: NSSearchToolbarItem? {
        toolbar?.items.first { $0.itemIdentifier == .workspaceSearch }
            as? NSSearchToolbarItem
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        ToolbarCatalogue.allowedIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        ToolbarCatalogue.defaultIdentifiers
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
        let isAvailable = !spec.requiresPDF || state.hasPDF

        for (subitem, subspec) in zip(subitems, spec.subitems) {
            subitem.target = target
            subitem.action = subspec.action
            subitem.toolTip = subspec.tooltip
            subitem.autovalidates = false
            subitem.isEnabled = isAvailable && subspec.isEnabled(state)
        }

        let selection = spec.selectedIndex?(state) ?? ToolbarCatalogue.noSelection
        selectedIndex = selection
        for index in subitems.indices {
            setSelected(index == selection, at: index)
        }
    }
}
