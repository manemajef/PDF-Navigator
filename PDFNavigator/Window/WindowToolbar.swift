import AppKit
//let defaultToolbarIdentifiers: [NSToolbarItem.Identifier] = [
//    .
//    
//]

final class WindowToolbar: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
    private weak var target: WindowController?
    private weak var toolbar: NSToolbar?
    private var hasPDF = false
    private var canGoBack = false
    private var canGoForward = false
    private var isZoomToFitActive = true
    private var isActualSizeActive = false
    private var isInspectorVisible = false
    private var inspectorSection = PDFInspectorSection.thumbnails

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

    func updateNavigation(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward

        if let subitems = navigationItem?.subitems, subitems.count >= 2 {
            subitems[0].isEnabled = canGoBack
            subitems[1].isEnabled = canGoForward
        }
        toolbar?.validateVisibleItems()
    }

    func updatePDFAvailability(_ hasPDF: Bool) {
        self.hasPDF = hasPDF

        searchItem?.endSearchInteraction()
        searchItem?.searchField.stringValue = ""

        let pdfIDs = pdfItemIdentifiers
        for item in toolbar?.items ?? [] {
            if pdfIDs.contains(item.itemIdentifier) {
                item.isHidden = !hasPDF
                item.isEnabled = hasPDF

                if let group = item as? NSToolbarItemGroup,
                   let spec = groupItemSpecs[item.itemIdentifier] {
                    group.updateSubitems(using: spec, target: target)
                }
            }
        }
    }

    func updateZoomControls(
        isZoomToFitActive: Bool,
        isActualSizeActive: Bool
    ) {
        self.isZoomToFitActive = isZoomToFitActive
        self.isActualSizeActive = isActualSizeActive

        guard
            let group = toolbar?.items.first(where: { $0.itemIdentifier == .pdfZoomControll }) as? NSToolbarItemGroup,
            let spec = groupItemSpecs[.pdfZoomControll]
        else {
            toolbar?.validateVisibleItems()
            return
        }

        group.updateSubitems(using: spec, target: target)
        toolbar?.validateVisibleItems()
    }

    func updateInspectorPresentation(
        isVisible: Bool,
        section: PDFInspectorSection
    ) {
        self.isInspectorVisible = isVisible
        inspectorSection = section

        guard
            let group = toolbar?.items.first(where: { $0.itemIdentifier == .readerPanels }) as? NSToolbarItemGroup,
            let spec = groupItemSpecs[.readerPanels]
        else { return }

        group.updateSubitems(using: spec, target: target)
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

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar, .sidebarTrackingSeparator, .workspaceNavigation,
            .workspaceHome, .workspaceNewTab, .workspaceSearch,
            .pdfPageNavigation,.pdfZoomControll,
            .pdfZoomIn, .pdfZoomOut, .pdfActualSize, .pdfZoomToFit,
            .pdfOpenExternally, .pdfShare, .space, .flexibleSpace,
            .inspectorTrackingSeparator, .readerPanels, .toggleInspector
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace, .toggleSidebar, .sidebarTrackingSeparator,
            .workspaceNavigation,
            .flexibleSpace,
            .pdfZoomControll,
            .pdfOpenExternally,
            .pdfShare,
            .space,
            .workspaceNewTab,
            .workspaceSearch,
            .toggleInspector,
        ]
    }

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

    // Completely lookup-based factory method without explicit switch cases
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        // 1. Single Button Items
        if let spec = Self.standardItemSpecs[identifier] {
            return NSToolbarItem(
                identifier: identifier,
                label: spec.label,
                symbolName: spec.symbol,
                target: target,
                action: spec.action,
                isEnabled: !spec.requiresPDF || hasPDF
            )
        }

        // 2. Grouped Items
        if let spec = groupItemSpecs[identifier] {
            return NSToolbarItemGroup.makeGroup(
                identifier: identifier,
                spec: spec,
                target: target
            )
        }

        // 3. Search Bar Item
        if identifier == .workspaceSearch {
            return NSSearchToolbarItem(
                identifier: identifier,
                label: "Search",
                placeholder: "Search Current PDF",
                target: target,
                action: #selector(WindowController.searchFieldSubmitted(_:)),
                delegate: self,
                isEnabled: hasPDF
            )
        }

        return nil
    }

    // MARK: - Declarative Specifications

    private struct StandardItemSpec {
        let label: String
        let symbol: String
        let action: Selector
        var requiresPDF: Bool = false
    }

    fileprivate struct GroupItemSpec {
        let label: String
        var isNavigational: Bool = false
        var selectedIndex: (() -> Int)? = nil
        let subitems: [GroupSubitemSpec]
    }

    fileprivate struct GroupSubitemSpec {
        let symbol: String
        let tooltip: String
        let action: Selector
        let isEnabled: () -> Bool
    }

    private static let standardItemSpecs: [NSToolbarItem.Identifier: StandardItemSpec] = [
        .workspaceNewTab: .init(
            label: "New Tab",
            symbol: "plus.rectangle.on.rectangle",
            action: #selector(WindowController.newTab(_:))
        ),

        .workspaceHome: .init(
            label: "Workspace Home",
            symbol: "house",
            action: #selector(WindowController.goToWorkspaceHome(_:))
        ),
        
        .pdfZoomIn: .init(
            label: "Zoom In",
            symbol: "plus.magnifyingglass",
            action: #selector(WindowController.zoomIn(_:)),
            requiresPDF: true),
        
        .pdfZoomOut: .init(
            label: "Zoom Out",
            symbol: "minus.magnifyingglass",
            action: #selector(WindowController.zoomOut(_:)),
            requiresPDF: true),
        
        .pdfActualSize: .init(
            label: "Actual Size",
            symbol: "1.magnifyingglass",
            action: #selector(WindowController.showActualSize(_:)),
            requiresPDF: true),
        
        .pdfZoomToFit: .init(
            label: "Zoom to Fit",
            symbol: "arrow.up.left.and.down.right.magnifyingglass",
            action: #selector(WindowController.zoomToFit(_:)),
            requiresPDF: true),
        
        .pdfOpenExternally: .init(
            label: "Open in Default App",
            symbol: "arrow.up.forward.app",
            action: #selector(WindowController.openCurrentPDFInDefaultApp(_:)),
            requiresPDF: true),
        
        .pdfShare: .init(
            label: "Share",
            symbol: "square.and.arrow.up",
            action: #selector(WindowController.shareCurrentPDF(_:)),
            requiresPDF: true),
        
    ]

    private var groupItemSpecs: [NSToolbarItem.Identifier: GroupItemSpec] {[
        .workspaceNavigation: GroupItemSpec(
            label: "Navigation",
            isNavigational: true,
            subitems: [
                .init(
                    symbol: "chevron.backward",
                    tooltip: "Back",
                    action: #selector(WindowController.goBack(_:)),
                    isEnabled: { [weak self] in self?.canGoBack ?? false }
                ),
                .init(
                    symbol: "chevron.forward",
                    tooltip: "Forward",
                    action: #selector(WindowController.goForward(_:)),
                    isEnabled: { [weak self] in self?.canGoForward ?? false }
                )
            ]
        ),
        
        .pdfPageNavigation: GroupItemSpec(
            label: "Page Navigation",
            subitems: [
                .init(
                    symbol: "chevron.up",
                    tooltip: "Previous Page",
                    action: #selector(WindowController.goToPreviousPage(_:)),
                    isEnabled: { [weak self] in self?.hasPDF ?? false }
                ),
                
                .init(
                    symbol: "chevron.down",
                    tooltip: "Next Page",
                    action: #selector(WindowController.goToNextPage(_:)),
                    isEnabled: { [weak self] in self?.hasPDF ?? false }
                )
            ]
        ),
        
        .pdfZoomControll: GroupItemSpec(
            label: "Zoom Controll",
            subitems: [
                .init(
                    symbol: "arrow.up.left.and.down.right.magnifyingglass",
                    tooltip: "Zoom to Fit",
                    action: #selector(WindowController.zoomToFit(_:)),
                    isEnabled: { [weak self] in
                    guard let self else { return false }
                    return hasPDF && !isZoomToFitActive
                }),
                
                .init(
                    symbol: "1.magnifyingglass",
                    tooltip: "Actual Size",
                    action: #selector(WindowController.showActualSize(_:)),
                    isEnabled: { [weak self] in
                    guard let self else { return false }
                    return hasPDF && !isActualSizeActive
                })
            ]
        ),
        
        .readerPanels: GroupItemSpec(
            label: "Reader Panels",
            selectedIndex: { [weak self] in
                guard let self, hasPDF, isInspectorVisible else { return -1 }
                return switch inspectorSection {
                case .thumbnails: 0
                case .outline: 1
                case .info: 2
                }
            },
            subitems: [
                .init(
                    symbol: "square.grid.2x2",
                    tooltip: "Thumbnails",
                    action: #selector(WindowController.toggleThumbnailsPanel(_:)),
                    isEnabled: { [weak self] in self?.hasPDF ?? false }
                ),
                .init(
                    symbol: "list.bullet.indent",
                    tooltip: "Table of Contents",
                    action: #selector(WindowController.toggleOutlinePanel(_:)),
                    isEnabled: { [weak self] in self?.hasPDF ?? false }
                ),
                .init(
                    symbol: "info",
                    tooltip: "Info",
                    action: #selector(WindowController.toggleInfoPanel(_:)),
                    isEnabled: { [weak self] in self?.hasPDF ?? false }
                )
            ]
        )
    ]}

    private var pdfItemIdentifiers: Set<NSToolbarItem.Identifier> {
        var set: Set<NSToolbarItem.Identifier> = [
            .workspaceSearch, .pdfPageNavigation, .pdfZoomControll,
            .readerPanels, .inspectorTrackingSeparator, .toggleInspector
        ]
        for (id, spec) in Self.standardItemSpecs where spec.requiresPDF {
            set.insert(id)
        }
        return set
    }

    private var searchItem: NSSearchToolbarItem? {
        toolbar?.items.first { $0.itemIdentifier == .workspaceSearch } as? NSSearchToolbarItem
    }

    private var navigationItem: NSToolbarItemGroup? {
        toolbar?.items.first { $0.itemIdentifier == .workspaceNavigation } as? NSToolbarItemGroup
    }
}

// MARK: - Declarative Helpers

private extension NSToolbarItem {
    convenience init(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        target: AnyObject?,
        action: Selector,
        isEnabled: Bool = true
    ) {
        self.init(itemIdentifier: identifier)
        configure(label: label, target: target, action: action)
        self.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        self.isEnabled = isEnabled
    }

    func configure(label: String, toolTip: String? = nil, target: AnyObject?, action: Selector?) {
        self.label = label
        self.paletteLabel = label
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
        delegate: NSSearchFieldDelegate?,
        isEnabled: Bool
    ) {
        self.init(itemIdentifier: identifier)
        self.label = label
        self.paletteLabel = label
        self.searchField.placeholderString = placeholder
        self.searchField.delegate = delegate
        self.searchField.target = target
        self.searchField.action = action
        self.isEnabled = isEnabled
    }
}

private extension NSToolbarItemGroup {
    static func makeGroup(
        identifier: NSToolbarItem.Identifier,
        spec: WindowToolbar.GroupItemSpec,
        target: AnyObject?
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

        group.updateSubitems(using: spec, target: target)
        return group
    }

    func updateSubitems(using spec: WindowToolbar.GroupItemSpec, target: AnyObject?) {
        for (subitem, subSpec) in zip(subitems, spec.subitems) {
            subitem.target = target
            subitem.action = subSpec.action
            subitem.toolTip = subSpec.tooltip
            subitem.autovalidates = false
            subitem.isEnabled = subSpec.isEnabled()
        }
        let desiredSelection = spec.selectedIndex?() ?? -1
        selectedIndex = desiredSelection
        for index in subitems.indices {
            setSelected(index == desiredSelection, at: index)
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let workspaceNavigation = Self("WorkspaceNavigation")
    static let workspaceHome = Self("WorkspaceHome")
    static let workspaceNewTab = Self("WorkspaceNewTab")
    static let workspaceSearch = Self("WorkspaceSearch")
    static let pdfPageNavigation = Self("PDFPageNavigation")
    static let pdfZoomIn = Self("PDFZoomIn")
    static let pdfZoomOut = Self("PDFZoomOut")
    static let pdfActualSize = Self("PDFActualSize")
    static let pdfZoomToFit = Self("PDFZoomToFit")
    static let pdfOpenExternally = Self("PDFOpenExternally")
    static let pdfShare = Self("PDFShare")
    static let pdfZoomControll = Self("PDFZoomControll")
    static let readerPanels = Self("ReaderPanels")
}
