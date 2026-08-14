import AppKit

/// What the toolbar contains: every item, how it looks, what it commands, and
/// when it is available.
///
/// Pure data. Adding or renaming a button is an edit here and nowhere else.
///
/// Availability rules are functions of `ToolbarState`, capturing nothing, which
/// is what lets these be `static let` and built once.
enum ToolbarCatalogue {

    // MARK: - Shapes

    /// A single button.
    ///
    /// Carries no `isEnabled` rule: top-level items self-validate through
    /// `WindowController.canPerform(_:)`, which owns enabled state. This type
    /// describes only what validation cannot express.
    struct Item {
        let label: String
        let symbol: String
        let action: Selector
    }

    /// A segmented cluster such as back/forward or the zoom controls.
    struct Group {
        let label: String
        var isNavigational = false
        /// Which segment reads as selected, or `nil` for a momentary group.
        var selectedIndex: ((ToolbarState) -> Int)? = nil
        let subitems: [Subitem]
    }

    /// One segment of a group.
    ///
    /// Group subitems run with `autovalidates` off, because AppKit validates a
    /// group as one unit and cannot express "back is available but forward is
    /// not". So each carries its own rule, applied during render.
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
        .goTolibrary: Item(
            label: "Library",
//            symbol: "house",

            symbol: "square.grid.4x3.fill",
            action: #selector(WindowController.goToLibrary(_:))
        ),
        .goToEnclosingFolder: Item(
            label: "Go to enclosing folder",
            symbol: "arrow.uturn.up",
            action: #selector(WindowController.goToEnclosingFolder(_:)),
            
        ),
        .goToStartPage: Item(
            label: "Go to Recents",
            //            symbol:"square.grid.4x3.fill",
            symbol: "clock",
            action: #selector(WindowController.goToStartPage(_: )),
        ),
        .pdfZoomIn: Item(
            label: "Zoom In",
            symbol: "plus.magnifyingglass",
            action: #selector(WindowController.zoomIn(_:))
        ),
        .pdfZoomOut: Item(
            label: "Zoom Out",
            symbol: "minus.magnifyingglass",
            action: #selector(WindowController.zoomOut(_:))
        ),
        .pdfActualSize: Item(
            label: "Actual Size",
            symbol: "1.magnifyingglass",
            action: #selector(WindowController.showActualSize(_:))
        ),
        .pdfZoomToFit: Item(
            label: "Scale to Fit",
            symbol: "arrow.down.left.and.arrow.up.right",
            action: #selector(WindowController.zoomToFit(_:))
        ),
        .pdfOpenExternally: Item(
            label: "Open in Default App",
            symbol: "arrow.up.forward.app",
            action: #selector(WindowController.openCurrentPDFInDefaultApp(_:))
        ),
        .pdfShare: Item(
            label: "Share",
            symbol: "square.and.arrow.up",
            action: #selector(WindowController.shareCurrentPDF(_:))
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
//            requiresPDF: true,
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

    // MARK: - Layout

    /// Everything the toolbar can hold, in palette order.
    ///
    /// Not filtered by mode. There is one toolbar and so one palette, and it
    /// has to offer the reader's tools even while browsing — the alternative is
    /// a palette that changes under the user, and an `allowed` list that omits
    /// items the saved arrangement still names.
    static let allIdentifiers: [NSToolbarItem.Identifier] = [
        .toggleSidebar, .sidebarTrackingSeparator, .workspaceNavigation,
        .workspaceNewTab, .openNewWorkspace, .workspaceSearch,
        .goTolibrary, .goToEnclosingFolder, .goToStartPage,
        .pdfPageNavigation, .pdfZoomControll,
        .pdfZoomIn, .pdfZoomOut, .pdfActualSize, .pdfZoomToFit,
        .pdfOpenExternally, .pdfShare, .space, .flexibleSpace,
        .inspectorTrackingSeparator, .readerPanels, .toggleInspector,
    ]

    /// The run every mode opens with.
    ///
    /// Shared by identity rather than by convention: both lists below splice in
    /// the same array, so these land on the same indices in every mode and a
    /// user's muscle memory survives the change. Keeping two hand-written lists
    /// in step would be a rule someone has to remember; this is a rule that
    /// cannot be broken.
    private static let leadingDefaults: [NSToolbarItem.Identifier] = [
        .toggleSidebar, .sidebarTrackingSeparator, .workspaceNavigation,
    ]

    /// The run that follows whatever the mode puts in the middle.
    private static let trailingDefaults: [NSToolbarItem.Identifier] = [
        .workspaceNewTab,
    ]

    /// The arrangement `mode` starts with, and what Restore Defaults puts back
    /// there. Written out per mode, since that is the whole of what a mode is
    /// here: the two runs differ in order and in padding, not only in which
    /// tools they carry, and neither is derivable from the other.
    ///
    /// Editing these only moves where a mode *starts*. Arrangements the user
    /// has made are their own, in `ToolbarArrangements`, and a reordering here
    /// does not disturb them.
    static func defaultIdentifiers(
        for mode: ToolbarMode
    ) -> [NSToolbarItem.Identifier] {
        switch mode {
        // Nothing in the middle: browsing is currently a strict subset of
        // reading, and navigation between locations belongs in the sidebar and
        // the library header, not up here. The empty middle is where Sort and
        // view-style go when they arrive.
        case .browsing:
            leadingDefaults
            + [.flexibleSpace]
                + trailingDefaults
            + [.workspaceSearch]

        // The reader's own tools trail the shared run because the inspector
        // toggle belongs against the right edge, over the inspector it opens.
        // The search field is here and not in browsing because it searches the
        // open PDF: over a library it would accept typing and do nothing.
        case .reading:
            leadingDefaults
                + [.flexibleSpace, .pdfZoomControll, .space, .goTolibrary]
                + trailingDefaults
                + [.workspaceSearch, .toggleInspector]
        }
    }

    #if DEBUG
    /// Checked when a toolbar is built, because both of these are mistakes a
    /// reader of the lists above would not catch.
    static func validate() {
        // `NSToolbarConfigPanel` inserts every allowed identifier into one
        // palette toolbar and raises on the second copy, so a duplicate here
        // fails on whoever opens Customize Toolbar rather than on whoever
        // wrote the list.
        assert(
            Set(allIdentifiers).count == allIdentifiers.count,
            "duplicate identifier in `allIdentifiers`"
        )
        // A default outside the palette cannot be dragged back once removed.
        for mode in [ToolbarMode.browsing, .reading] {
            assert(
                Set(defaultIdentifiers(for: mode)).isSubset(of: Set(allIdentifiers)),
                "\(mode) defaults contain an identifier missing from `allIdentifiers`"
            )
        }
    }
    #endif
}

extension NSToolbarItem.Identifier {
    static let workspaceNavigation = Self("WorkspaceNavigation")
    // Warning: the raw string is a persisted key. AppKit saves the user's
    // toolbar arrangement under it, so changing it discards their layout.
    static let goTolibrary = Self("GoToLibrary")
    static let goToEnclosingFolder = Self("GoToEnclosingFolder")
    static let goToStartPage = Self("GoToStartPage")
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
