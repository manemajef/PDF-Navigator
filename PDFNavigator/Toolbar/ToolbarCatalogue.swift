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
        var modes: Set<ToolbarMode> = [.browsing, .reading]
    }

    /// A segmented cluster such as back/forward or the zoom controls.
    struct Group {
        let label: String
        var isNavigational = false
        var modes: Set<ToolbarMode> = [.browsing, .reading]
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
            action: #selector(WindowController.zoomIn(_:)),
//            requiresPDF: true
            modes: [.reading]
        ),
        .pdfZoomOut: Item(
            label: "Zoom Out",
            symbol: "minus.magnifyingglass",
            action: #selector(WindowController.zoomOut(_:)),
            modes: [.reading]

        ),
        .pdfActualSize: Item(
            label: "Actual Size",
            symbol: "1.magnifyingglass",
            action: #selector(WindowController.showActualSize(_:)),
            modes: [.reading]

        ),
        .pdfZoomToFit: Item(
            label: "Scale to Fit",
            symbol: "arrow.down.left.and.arrow.up.right",
            action: #selector(WindowController.zoomToFit(_:)),
            modes: [.reading]

        ),
        .pdfOpenExternally: Item(
            label: "Open in Default App",
            symbol: "arrow.up.forward.app",
            action: #selector(WindowController.openCurrentPDFInDefaultApp(_:)),
            modes: [.reading]

        ),
        .pdfShare: Item(
            label: "Share",
            symbol: "square.and.arrow.up",
            action: #selector(WindowController.shareCurrentPDF(_:)),
            modes: [.reading]

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
            modes: [.reading],
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
            modes: [.reading],
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
            modes: [.reading],
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

    static let systemItemModes: [NSToolbarItem.Identifier: Set<ToolbarMode>] = [
        .inspectorTrackingSeparator: [.reading],
        .toggleInspector: [.reading],
        // The field searches the open PDF, so while browsing it would be a
        // control that accepts typing and does nothing. Drop this line to offer
        // it in both palettes again.
        .workspaceSearch: [.reading],
    ]

    static func isVisible(
        _ identifier: NSToolbarItem.Identifier,
        in mode: ToolbarMode
    ) -> Bool {
        if let item = items[identifier] { return item.modes.contains(mode)}
        if let group = groups[identifier] {return group.modes.contains(mode)}
        if let modes = systemItemModes[identifier] { return modes.contains(mode)}
        return true
    }
    

    // MARK: - Layout

    /// The pool every schema draws from. The order here is palette order.
    ///
    /// No schema uses this list directly: each filters it through `isVisible`,
    /// so a reading-only tool cannot reach the browsing palette by being
    /// listed in the wrong place.
    static let allIdentifiers: [NSToolbarItem.Identifier] = [
        .toggleSidebar, .sidebarTrackingSeparator, .workspaceNavigation,
        .workspaceNewTab, .openNewWorkspace, .workspaceSearch,
        .goTolibrary, .goToEnclosingFolder, .goToStartPage,
        .pdfPageNavigation, .pdfZoomControll,
        .pdfZoomIn, .pdfZoomOut, .pdfActualSize, .pdfZoomToFit,
        .pdfOpenExternally, .pdfShare, .space, .flexibleSpace,
        .inspectorTrackingSeparator, .readerPanels, .toggleInspector,
    ]

    /// The run every schema opens with.
    ///
    /// Shared by identity rather than by convention: both schemas splice in the
    /// same array, so these land on the same indices in every mode and a user's
    /// muscle memory survives the swap. Keeping two hand-written lists in step
    /// would be a rule someone has to remember; this is a rule that cannot be
    /// broken.
    private static let leadingDefaults: [NSToolbarItem.Identifier] = [
        .toggleSidebar, .sidebarTrackingSeparator, .workspaceNavigation,
    ]

    /// The run that follows whatever the mode puts in the middle.
    private static let trailingDefaults: [NSToolbarItem.Identifier] = [
        .workspaceNewTab,
    ]

    /// Browsing the library or recents.
    ///
    /// Nothing in the middle: browsing is currently a strict subset of reading,
    /// and navigation between locations belongs in the sidebar and the library
    /// header, not up here. The empty middle is where Sort and view-style go
    /// when they arrive.
    static let browsingSchema = ToolbarSchema(
        identifier: "BrowsingToolbarV1",
        allowed: allIdentifiers.filter { isVisible($0, in: .browsing) },
        defaults: leadingDefaults
            + [.flexibleSpace]
            + trailingDefaults
    )

    /// Reading a PDF.
    ///
    /// The reader's own tools trail the shared run because the inspector toggle
    /// belongs against the right edge, over the inspector it opens.
    static let readingSchema = ToolbarSchema(
        identifier: "ReadingToolbarV1",
        allowed: allIdentifiers.filter { isVisible($0, in: .reading) },
        defaults: leadingDefaults
            + [.flexibleSpace, .pdfZoomControll, .space, .goTolibrary]
            + trailingDefaults
            + [.workspaceSearch, .toggleInspector]
    )

    static func schema(for mode: ToolbarMode) -> ToolbarSchema {
        switch mode {
        case .browsing: browsingSchema
        case .reading: readingSchema
        }
    }

    /// The schema a live toolbar was built from, matched on the identifier the
    /// two share. `nil` for any toolbar this catalogue did not build.
    static func schema(matching toolbar: NSToolbar) -> ToolbarSchema? {
        [browsingSchema, readingSchema]
            .first { $0.identifier == toolbar.identifier }
    }
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
