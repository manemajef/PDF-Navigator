import AppKit

/// One toolbar's identity and layout.
///
/// Two schemas mean two `NSToolbar`s, swapped as the window changes mode. That
/// is what buys a per-mode *arrangement*: hiding items can only punch holes in
/// one shared order, so it can never move a tool or reposition a spacer.
///
/// `identifier` doubles as the autosave key, so each schema keeps its own saved
/// customization — an arrangement made while reading leaves the browsing one
/// alone.
struct ToolbarSchema {
    let identifier: String

    /// Everything the customization palette offers, in palette order.
    let allowed: [NSToolbarItem.Identifier]

    /// The arrangement a window starts with, in toolbar order. Repeats are
    /// meaningful here: two flexible spaces is how a cluster gets centred.
    let defaults: [NSToolbarItem.Identifier]

    init(
        identifier: String,
        allowed: [NSToolbarItem.Identifier],
        defaults: [NSToolbarItem.Identifier]
    ) {
        // The duplicate case is a crash, not a warning: `NSToolbarConfigPanel`
        // inserts every allowed identifier into one palette toolbar and raises
        // on the second copy — so the failure lands on whoever opens Customize
        // Toolbar rather than on whoever wrote the list.
        assert(
            Set(allowed).count == allowed.count,
            "\(identifier): duplicate identifier in `allowed`"
        )
        // A default outside `allowed` cannot be dragged back once removed, so
        // the palette and the toolbar disagree about what exists.
        assert(
            Set(defaults).isSubset(of: Set(allowed)),
            "\(identifier): `defaults` contains an identifier missing from `allowed`"
        )

        self.identifier = identifier
        self.allowed = allowed
        self.defaults = defaults
    }
}
