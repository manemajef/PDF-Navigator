import AppKit

/// What the toolbar contains: every item, how it looks, what it commands, and
/// when it is available.
///
/// Pure data, and separate from `WindowToolbar` because the two change for
/// different reasons. Adding or renaming a button is an edit here and nowhere
/// else; changing *how* items are built or rendered is an edit there and
/// nowhere else.
///
/// Availability rules are plain functions of `ToolbarState` rather than
/// closures capturing a toolbar. That is what lets these be `static let`,
/// built once, instead of a computed property that rebuilt every closure on
/// each access.
enum ToolbarCatalogue {

    // MARK: - Shapes

    /// A single button.
    ///
    /// There is no `isEnabled` rule here on purpose: top-level items
    /// self-validate through `WindowController.canPerform(_:)`, so enabled
    /// state already has one owner. This type only describes what validation
    /// cannot express.
    struct Item {
        let label: String
        let symbol: String
        let action: Selector
        var requiresPDF = false
    }

    /// A segmented cluster such as back/forward or the zoom controls.
    struct Group {
        let label: String
        var isNavigational = false
        var requiresPDF = false
        /// Which segment reads as selected, or `nil` for a momentary group
        /// where none ever does.
        var selectedIndex: ((ToolbarState) -> Int)? = nil
        let subitems: [Subitem]
    }

    /// One segment of a group.
    ///
    /// Unlike top-level items, group subitems have `autovalidates` turned off —
    /// AppKit validates a group as a whole, which cannot express "back is
    /// available but forward is not". So these *do* carry their own rule, and
    /// the render pass applies it.
    struct Subitem {
        let symbol: String
        let tooltip: String
        let action: Selector
        var isEnabled: (ToolbarState) -> Bool = { _ in true }
    }

    // MARK: - Inventory

    static let items: [NSToolbarItem.Identifier: Item] = [
        .workspaceNewTab: Item(
            label: "New Tab",
            symbol: "plus.square.on.square",
            action: #selector(WindowController.newTab(_:))
        ),
        .openNewWorkspace: Item(
            label: "Open Workspace",
            symbol: "folder.badge.plus",
            action: #selector(WindowController.openNewWorkspace(_:))
        ),
        .workspaceHome: Item(
            label: "Workspace Home",
            symbol: "house",
            action: #selector(WindowController.goToWorkspaceHome(_:))
        ),
        .pdfZoomIn: Item(
            label: "Zoom In",
            symbol: "plus.magnifyingglass",
            action: #selector(WindowController.zoomIn(_:)),
            requiresPDF: true
        ),
        .pdfZoomOut: Item(
            label: "Zoom Out",
            symbol: "minus.magnifyingglass",
            action: #selector(WindowController.zoomOut(_:)),
            requiresPDF: true
        ),
        .pdfActualSize: Item(
            label: "Actual Size",
            symbol: "1.magnifyingglass",
            action: #selector(WindowController.showActualSize(_:)),
            requiresPDF: true
        ),
        .pdfZoomToFit: Item(
            label: "Scale to Fit",
            symbol: "arrow.down.left.and.arrow.up.right",
            action: #selector(WindowController.zoomToFit(_:)),
            requiresPDF: true
        ),
        .pdfOpenExternally: Item(
            label: "Open in Default App",
            symbol: "arrow.up.forward.app",
            action: #selector(WindowController.openCurrentPDFInDefaultApp(_:)),
            requiresPDF: true
        ),
        .pdfShare: Item(
            label: "Share",
            symbol: "square.and.arrow.up",
            action: #selector(WindowController.shareCurrentPDF(_:)),
            requiresPDF: true
        ),
    ]

    static let groups: [NSToolbarItem.Identifier: Group] = [
        .workspaceNavigation: Group(
            label: "Navigation",
            isNavigational: true,
            subitems: [
                Subitem(
                    symbol: "chevron.backward",
                    tooltip: "Back",
                    action: #selector(WindowController.goBack(_:)),
                    isEnabled: { $0.canGoBack }
                ),
                Subitem(
                    symbol: "chevron.forward",
                    tooltip: "Forward",
                    action: #selector(WindowController.goForward(_:)),
                    isEnabled: { $0.canGoForward }
                ),
            ]
        ),

        .pdfPageNavigation: Group(
            label: "Page Navigation",
            requiresPDF: true,
            subitems: [
                Subitem(
                    symbol: "chevron.up",
                    tooltip: "Previous Page",
                    action: #selector(WindowController.goToPreviousPage(_:))
                ),
                Subitem(
                    symbol: "chevron.down",
                    tooltip: "Next Page",
                    action: #selector(WindowController.goToNextPage(_:))
                ),
            ]
        ),

        .pdfZoomControll: Group(
            label: "Zoom",
            requiresPDF: true,
            subitems: [
                Subitem(
                    symbol: "minus.magnifyingglass",
                    tooltip: "Zoom Out",
                    action: #selector(WindowController.zoomOut(_:))
                ),
                Subitem(
                    symbol: "1.magnifyingglass",
                    tooltip: "Actual Size",
                    action: #selector(WindowController.showActualSize(_:)),
                    isEnabled: { !$0.isActualSizeActive }
                ),
                Subitem(
                    symbol: "plus.magnifyingglass",
                    tooltip: "Zoom In",
                    action: #selector(WindowController.zoomIn(_:))
                ),
            ]
        ),

        .readerPanels: Group(
            label: "Reader Panels",
            requiresPDF: true,
            selectedIndex: { state in
                switch state.inspectorSection {
                case .thumbnails: 0
                case .outline: 1
                case .info: 2
                case nil: Self.noSelection
                }
            },
            subitems: [
                Subitem(
                    symbol: "square.grid.2x2",
                    tooltip: "Thumbnails",
                    action: #selector(WindowController.toggleThumbnailsPanel(_:))
                ),
                Subitem(
                    symbol: "list.bullet.indent",
                    tooltip: "Table of Contents",
                    action: #selector(WindowController.toggleOutlinePanel(_:))
                ),
                Subitem(
                    symbol: "info",
                    tooltip: "Info",
                    action: #selector(WindowController.toggleInfoPanel(_:))
                ),
            ]
        ),
    ]

    /// AppKit's own value for "no segment is selected".
    static let noSelection = -1

    /// Items that only make sense while a PDF is open, including the ones
    /// AppKit supplies rather than this catalogue.
    ///
    /// Visibility is the toolbar's own business: unlike enabled state, AppKit
    /// offers no validation hook for it, so it has to be rendered.
    static let pdfOnlyIdentifiers: Set<NSToolbarItem.Identifier> = {
        var identifiers: Set<NSToolbarItem.Identifier> = [
            .workspaceSearch, .inspectorTrackingSeparator, .toggleInspector,
        ]
        for (identifier, item) in items where item.requiresPDF {
            identifiers.insert(identifier)
        }
        for (identifier, group) in groups where group.requiresPDF {
            identifiers.insert(identifier)
        }
        return identifiers
    }()

    // MARK: - Layout

    static let allowedIdentifiers: [NSToolbarItem.Identifier] = [
        .toggleSidebar, .sidebarTrackingSeparator, .workspaceNavigation,
        .workspaceHome, .workspaceNewTab, .openNewWorkspace, .workspaceSearch,
        .pdfPageNavigation, .pdfZoomControll,
        .pdfZoomIn, .pdfZoomOut, .pdfActualSize, .pdfZoomToFit,
        .pdfOpenExternally, .pdfShare, .space, .flexibleSpace,
        .inspectorTrackingSeparator, .readerPanels, .toggleInspector,
    ]

    static let defaultIdentifiers: [NSToolbarItem.Identifier] = [
        .flexibleSpace, .toggleSidebar, .sidebarTrackingSeparator,
        .workspaceNavigation,
        .flexibleSpace,
        .pdfZoomControll,
        .space,
        .pdfZoomToFit,
        .workspaceNewTab,
        .workspaceSearch,
        .toggleInspector,
    ]
}

extension NSToolbarItem.Identifier {
    static let workspaceNavigation = Self("WorkspaceNavigation")
    static let workspaceHome = Self("WorkspaceHome")
    static let workspaceNewTab = Self("WorkspaceNewTab")
    static let openNewWorkspace = Self("OpenNewWorkspace")
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
