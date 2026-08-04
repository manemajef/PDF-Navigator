import AppKit

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
        let toolbar = NSToolbar(identifier: "WorkspaceToolbarV3")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true

        self.toolbar = toolbar
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

    func endSearch() {
        searchItem?.endSearchInteraction()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let searchField = notification.object as? NSSearchField else { return }
        target?.searchFieldChanged(searchField)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        allowedItemIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        defaultItemIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .workspaceNewFolder:
            makeItem(identifier: itemIdentifier, label: "New Folder", symbolName: "+", action: #selector(WindowController.newTab(_:)))
        case .workspaceNavigation:
            makeNavigationItem(itemIdentifier)
        case .workspaceNewTab:
            makeItem(
                identifier: itemIdentifier,
                label: "New Tab",
                symbolName: "plus.rectangle.on.rectangle",
                action: #selector(WindowController.newTab(_:))
            )
        case .workspaceSearch:
            makeSearchItem(itemIdentifier)
        case .pdfPageNavigation:
            makePageNavigationItem(itemIdentifier)
        case .pdfZoomIn:
            makePDFItem(
                identifier: itemIdentifier,
                label: "Zoom In",
                symbolName: "plus.magnifyingglass",
                action: #selector(WindowController.zoomIn(_:))
            )
        case .pdfZoomOut:
            makePDFItem(
                identifier: itemIdentifier,
                label: "Zoom Out",
                symbolName: "minus.magnifyingglass",
                action: #selector(WindowController.zoomOut(_:))
            )
        case .pdfActualSize:
            makePDFItem(
                identifier: itemIdentifier,
                label: "Actual Size",
                symbolName: "1.magnifyingglass",
                action: #selector(WindowController.showActualSize(_:))
            )
        case .pdfZoomToFit:
            makePDFItem(
                identifier: itemIdentifier,
                label: "Zoom to Fit",
                symbolName: "arrow.up.left.and.arrow.down.right",
                action: #selector(WindowController.zoomToFit(_:))
            )
        case .pdfOpenExternally:
            makePDFItem(
                identifier: itemIdentifier,
                label: "Open in Default App",
                symbolName: "arrow.up.forward.app",
                action: #selector(WindowController.openCurrentPDFInDefaultApp(_:))
            )
        case .pdfShare:
            makePDFItem(
                identifier: itemIdentifier,
                label: "Share",
                symbolName: "square.and.arrow.up",
                action: #selector(WindowController.shareCurrentPDF(_:))
            )
        default:
            nil
        }
    }

    private var allowedItemIdentifiers: [NSToolbarItem.Identifier] {
        [
            .workspaceNewFolder,
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
            .flexibleSpace
        ]
    }

    private var defaultItemIdentifiers: [NSToolbarItem.Identifier] {
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
            .workspaceSearch
        ]
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
            .pdfShare
        ]
    }

    func updatePDFAvailability(_ hasPDF: Bool) {
        self.hasPDF = hasPDF

        searchItem?.endSearchInteraction()
        searchItem?.searchField.stringValue = ""

        for item in toolbar?.items ?? [] {
            if pdfItemIdentifiers.contains(item.itemIdentifier) {
                item.isHidden = !hasPDF
            }
        }
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
            WindowController.goBack(_:)
        )
        backItem.toolTip = "Back"
        backItem.autovalidates = false
        backItem.isEnabled = canGoBack

        let forwardItem = item.subitems[1]
        forwardItem.target = target
        forwardItem.action = #selector(
            WindowController.goForward(_:)
        )
        forwardItem.toolTip = "Forward"
        forwardItem.autovalidates = false
        forwardItem.isEnabled = canGoForward

        return item
    }

    private func makePageNavigationItem(
        _ identifier: NSToolbarItem.Identifier
    ) -> NSToolbarItemGroup? {
        let labels = ["Previous Page", "Next Page"]
        let images = [
            NSImage(
                systemSymbolName: "chevron.up",
                accessibilityDescription: labels[0]
            ),
            NSImage(
                systemSymbolName: "chevron.down",
                accessibilityDescription: labels[1]
            )
        ].compactMap { $0 }

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
        item.isHidden = !hasPDF

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
        item.searchField.isContinuous = false
        item.isHidden = !hasPDF
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
        item.isHidden = !hasPDF
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
    static let workspaceNewFolder = NSToolbarItem.Identifier("WorkspaceNewFolder")
    static let workspaceSearch = NSToolbarItem.Identifier("WorkspaceSearch")
    static let pdfPageNavigation = NSToolbarItem.Identifier("PDFPageNavigation")
    static let pdfZoomIn = NSToolbarItem.Identifier("PDFZoomIn")
    static let pdfZoomOut = NSToolbarItem.Identifier("PDFZoomOut")
    static let pdfActualSize = NSToolbarItem.Identifier("PDFActualSize")
    static let pdfZoomToFit = NSToolbarItem.Identifier("PDFZoomToFit")
    static let pdfOpenExternally = NSToolbarItem.Identifier("PDFOpenExternally")
    static let pdfShare = NSToolbarItem.Identifier("PDFShare")
}
