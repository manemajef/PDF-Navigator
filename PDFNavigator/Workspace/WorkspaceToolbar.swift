import AppKit

final class WorkspaceToolbar: NSObject, NSToolbarDelegate {
    private weak var target: WorkspaceWindowController?
    private weak var navigationItem: NSToolbarItemGroup?
    private weak var searchItem: NSSearchToolbarItem?
    private var canGoBack = false
    private var canGoForward = false

    init(target: WorkspaceWindowController) {
        self.target = target
    }

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "WorkspaceToolbarV3")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        return toolbar
    }

    func updateNavigation(
        canGoBack: Bool,
        canGoForward: Bool
    ) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        guard let navigationItem else {
            return
        }
        navigationItem.subitems[0].isEnabled = canGoBack
        navigationItem.subitems[1].isEnabled = canGoForward
    }

    func beginSearch() {
        searchItem?.beginSearchInteraction()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        itemIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        itemIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .workspaceNavigation:
            makeNavigationItem(itemIdentifier)
        case .workspaceNewTab:
            makeItem(
                identifier: itemIdentifier,
                label: "New Tab",
                symbolName: "plus",
                action: #selector(WorkspaceWindowController.newWorkspaceTab(_:))
            )
        case .workspaceSearch:
            makeSearchItem(itemIdentifier)
        default:
            nil
        }
    }

    private var itemIdentifiers: [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceNavigation,
            .flexibleSpace,
            .workspaceNewTab,
            .workspaceSearch
        ]
    }

    private func makeNavigationItem(
        _ identifier: NSToolbarItem.Identifier
    ) -> NSToolbarItemGroup? {
        let labels = ["Back", "Forward"]

        let images = [
            NSImage(
                systemSymbolName: "chevron.backward",
                accessibilityDescription: labels[0]
            ),
            NSImage(
                systemSymbolName: "chevron.forward",
                accessibilityDescription: labels[1]
            )
        ].compactMap { $0 }

        guard images.count == labels.count else {
            return nil
        }

        let item = NSToolbarItemGroup(
            itemIdentifier: identifier,
            images: images,
            selectionMode: .momentary,
            labels: labels,
            target: nil,
            action: nil
        )

        item.label = "Navigation"
        item.paletteLabel = "Navigation"
        item.isNavigational = true
        item.controlRepresentation = .expanded

        let backItem = item.subitems[0]
        backItem.target = target
        backItem.action = #selector(
            WorkspaceWindowController.goBack(_:)
        )
        backItem.toolTip = "Back"
        backItem.autovalidates = false
        backItem.isEnabled = canGoBack

        let forwardItem = item.subitems[1]
        forwardItem.target = target
        forwardItem.action = #selector(
            WorkspaceWindowController.goForward(_:)
        )
        forwardItem.toolTip = "Forward"
        forwardItem.autovalidates = false
        forwardItem.isEnabled = canGoForward

        navigationItem = item

        return item
    }

    private func makeSearchItem(
        _ identifier: NSToolbarItem.Identifier
    ) -> NSSearchToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: identifier)
        item.label = "Search"
        item.paletteLabel = "Search"
        item.searchField.placeholderString = "Search Current PDF"
        item.searchField.target = target
        item.searchField.action = #selector(WorkspaceWindowController.searchFieldChanged(_:))
        item.searchField.isContinuous = true
        searchItem = item
        return item
    }

    private func makeItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.target = target
        item.action = action
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        return item
    }
}

private extension NSToolbarItem.Identifier {
    static let workspaceNavigation = NSToolbarItem.Identifier("WorkspaceNavigation")
    static let workspaceNewTab = NSToolbarItem.Identifier("WorkspaceNewTab")
    static let workspaceSearch = NSToolbarItem.Identifier("WorkspaceSearch")
}
