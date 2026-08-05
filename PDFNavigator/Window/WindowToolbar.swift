import AppKit

/// The native window toolbar and its item state.
final class WindowToolbar: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
    private weak var target: WindowController?
    private weak var toolbar: NSToolbar?
    private var hasPDF = false
    private var canGoBack = false
    private var canGoForward = false

    init(target: WindowController) {
        self.target = target
    }

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "WorkspaceToolbarV7")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        self.toolbar = toolbar
        return toolbar
    }

    func updateNavigation(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward

        guard let navigationItem else { return }
        navigationItem.subitems[0].isEnabled = canGoBack
        navigationItem.subitems[1].isEnabled = canGoForward
    }

    func updatePDFAvailability(_ hasPDF: Bool) {
        self.hasPDF = hasPDF

        searchItem?.endSearchInteraction()
        searchItem?.searchField.stringValue = ""

        for item in toolbar?.items ?? [] {
            if pdfItemIdentifiers.contains(item.itemIdentifier) {
                item.isHidden = !hasPDF
                item.isEnabled = hasPDF
            }
        }
    }

    func beginSearch() {
        guard hasPDF else { return }
        searchItem?.beginSearchInteraction()
    }

    func endSearch() {
        searchItem?.endSearchInteraction()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let searchField = notification.object as? NSSearchField else { return }
        target?.searchFieldChanged(searchField)
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceNavigation,
            .workspaceNewTab,
            .workspaceSearch,
            .pdfPageNavigation,
            .pdfZoomIn,
            .pdfZoomOut,
            .pdfActualSize,
            .pdfZoomToFit,
            .pdfOpenExternally,
            .pdfShare,
            .space,
            .flexibleSpace,
            .inspectorTrackingSeparator,
            .toggleInspector,
        ]
    }

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceNavigation,
            .flexibleSpace,
            .pdfActualSize,
            .pdfZoomToFit,
            .flexibleSpace,
            .workspaceNewTab,
            .workspaceSearch,
//            .inspectorTrackingSeparator,
            .toggleInspector,
        ]
    }

    func toolbarWillAddItem(_ notification: Notification) {
        guard
            let item = notification.userInfo?[NSToolbarUserInfoKey.itemKey]
                as? NSToolbarItem,
            item.itemIdentifier == NSToolbarItem.Identifier.toggleSidebar
        else { return }

        item.target = target
        item.action = #selector(WindowController.toggleSidebar(_:))
        item.label = "Navigator"
        item.paletteLabel = "Navigator"
        item.toolTip = "Toggle Navigator"
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch identifier {
        case .workspaceNavigation:
            makeNavigationItem(identifier)
        case .workspaceNewTab:
            makeItem(
                identifier: identifier,
                label: "New Tab",
                symbolName: "plus.rectangle.on.rectangle",
                action: #selector(WindowController.newTab(_:))
            )
        case .workspaceSearch:
            makeSearchItem(identifier)
        case .pdfPageNavigation:
            makePageNavigationItem(identifier)
        case .pdfZoomIn:
            makePDFItem(
                identifier: identifier,
                label: "Zoom In",
                symbolName: "plus.magnifyingglass",
                action: #selector(WindowController.zoomIn(_:))
            )
        case .pdfZoomOut:
            makePDFItem(
                identifier: identifier,
                label: "Zoom Out",
                symbolName: "minus.magnifyingglass",
                action: #selector(WindowController.zoomOut(_:))
            )
        case .pdfActualSize:
            makePDFItem(
                identifier: identifier,
                label: "Actual Size",
                symbolName: "1.magnifyingglass",
                action: #selector(WindowController.showActualSize(_:))
            )
        case .pdfZoomToFit:
            makePDFItem(
                identifier: identifier,
                label: "Zoom to Fit",
                symbolName: "arrow.up.left.and.down.right.magnifyingglass",
                action: #selector(WindowController.zoomToFit(_:))
            )
        case .pdfOpenExternally:
            makePDFItem(
                identifier: identifier,
                label: "Open in Default App",
                symbolName: "arrow.up.forward.app",
                action: #selector(WindowController.openCurrentPDFInDefaultApp(_:))
            )
        case .pdfShare:
            makePDFItem(
                identifier: identifier,
                label: "Share",
                symbolName: "square.and.arrow.up",
                action: #selector(WindowController.shareCurrentPDF(_:))
            )
        case .toggleInspector:
            makeItem(
                identifier: identifier,
                label: "Inspector",
                symbolName: "sidebar.right",
                action: #selector(WindowController.toggleInspector(_:))
            )
        default:
            nil
        }
    }

    private var pdfItemIdentifiers: Set<NSToolbarItem.Identifier> {
        [
            .workspaceSearch,
            .pdfPageNavigation,
            .pdfZoomIn,
            .pdfZoomOut,
            .pdfActualSize,
            .pdfZoomToFit,
            .pdfOpenExternally,
            .pdfShare,
        ]
    }

    private var searchItem: NSSearchToolbarItem? {
        toolbar?.items.first {
            $0.itemIdentifier == .workspaceSearch
        } as? NSSearchToolbarItem
    }

    private var navigationItem: NSToolbarItemGroup? {
        toolbar?.items.first {
            $0.itemIdentifier == .workspaceNavigation
        } as? NSToolbarItemGroup
    }

    private func makeNavigationItem(
        _ identifier: NSToolbarItem.Identifier
    ) -> NSToolbarItemGroup? {
        let labels = ["Back", "Forward"]
        let images = labels.enumerated().compactMap { index, label in
            NSImage(
                systemSymbolName: index == 0 ? "chevron.backward" : "chevron.forward",
                accessibilityDescription: label
            )
        }
        guard images.count == labels.count else { return nil }

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

        item.subitems[0].target = target
        item.subitems[0].action = #selector(WindowController.goBack(_:))
        item.subitems[0].toolTip = labels[0]
        item.subitems[0].autovalidates = false
        item.subitems[0].isEnabled = canGoBack

        item.subitems[1].target = target
        item.subitems[1].action = #selector(WindowController.goForward(_:))
        item.subitems[1].toolTip = labels[1]
        item.subitems[1].autovalidates = false
        item.subitems[1].isEnabled = canGoForward
        return item
    }

    private func makePageNavigationItem(
        _ identifier: NSToolbarItem.Identifier
    ) -> NSToolbarItemGroup? {
        let labels = ["Previous Page", "Next Page"]
        let images = labels.enumerated().compactMap { index, label in
            NSImage(
                systemSymbolName: index == 0 ? "chevron.up" : "chevron.down",
                accessibilityDescription: label
            )
        }
        guard images.count == labels.count else { return nil }

        let item = NSToolbarItemGroup(
            itemIdentifier: identifier,
            images: images,
            selectionMode: .momentary,
            labels: labels,
            target: nil,
            action: nil
        )
        item.label = "Page Navigation"
        item.paletteLabel = "Page Navigation"
        item.controlRepresentation = .expanded
        item.isEnabled = hasPDF

        item.subitems[0].target = target
        item.subitems[0].action = #selector(WindowController.goToPreviousPage(_:))
        item.subitems[0].toolTip = labels[0]
        item.subitems[1].target = target
        item.subitems[1].action = #selector(WindowController.goToNextPage(_:))
        item.subitems[1].toolTip = labels[1]
        return item
    }

    private func makeSearchItem(
        _ identifier: NSToolbarItem.Identifier
    ) -> NSSearchToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: identifier)
        item.label = "Search"
        item.paletteLabel = "Search"
        item.searchField.placeholderString = "Search Current PDF"
        item.searchField.delegate = self
        item.searchField.target = target
        item.searchField.action = #selector(WindowController.searchFieldSubmitted(_:))
        item.isEnabled = hasPDF
        return item
    }

    private func makePDFItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = makeItem(
            identifier: identifier,
            label: label,
            symbolName: symbolName,
            action: action
        )
        item.isEnabled = hasPDF
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
        item.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: label
        )
        return item
    }
}

private extension NSToolbarItem.Identifier {
    static let workspaceNavigation = Self("WorkspaceNavigation")
    static let workspaceNewTab = Self("WorkspaceNewTab")
    static let workspaceSearch = Self("WorkspaceSearch")
    static let pdfPageNavigation = Self("PDFPageNavigation")
    static let pdfZoomIn = Self("PDFZoomIn")
    static let pdfZoomOut = Self("PDFZoomOut")
    static let pdfActualSize = Self("PDFActualSize")
    static let pdfZoomToFit = Self("PDFZoomToFit")
    static let pdfOpenExternally = Self("PDFOpenExternally")
    static let pdfShare = Self("PDFShare")
    static let toggleInspector = Self("ToggleInspector")
}
