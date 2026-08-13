import AppKit

/// The toolbar's arrangement, one per mode, remembered across launches.
///
/// This is what `NSToolbar.autosavesConfiguration` would do, except that it
/// saves one arrangement per toolbar identifier and the window has two modes
/// sharing a single toolbar. Storing them here is what lets the reader's items
/// be *absent* while browsing rather than merely hidden — and an absent item is
/// one the customization palette cannot pop back into view.
final class ToolbarArrangements {
    static let shared = ToolbarArrangements()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Debug builds start from the catalogue's defaults every launch, so an
        // edit to those lists is visible on the next run instead of being
        // masked by an arrangement saved while testing. This is what the old
        // `#if !DEBUG` around `autosavesConfiguration` bought; clearing here
        // rather than branching the storage leaves one read/write path, which
        // is the path that ships.
        #if DEBUG
        for mode in [ToolbarMode.browsing, .reading] {
            defaults.removeObject(forKey: Self.key(for: mode))
        }
        #endif
    }

    /// What the toolbar should hold in `mode`: the user's arrangement, or the
    /// catalogue's defaults until they make one.
    func arrangement(for mode: ToolbarMode) -> [NSToolbarItem.Identifier] {
        guard let saved = storedArrangement(for: mode) else {
            return ToolbarCatalogue.defaultIdentifiers(for: mode)
        }

        // An identifier the catalogue no longer offers is dropped rather than
        // handed to AppKit, which would ask the delegate for an item nothing
        // can build. This is the upgrade path for a renamed or retired tool.
        let allowed = Set(ToolbarCatalogue.allIdentifiers)
        return saved
            .map(NSToolbarItem.Identifier.init(rawValue:))
            .filter(allowed.contains)
    }

    /// Records `identifiers` as the arrangement for `mode`.
    ///
    /// Called far more often than the arrangement actually changes — the window
    /// captures on every pass of the event loop — so an unchanged list writes
    /// nothing.
    func setArrangement(_ identifiers: [NSToolbarItem.Identifier], for mode: ToolbarMode) {
        let raw = identifiers.map(\.rawValue)
        guard raw != storedArrangement(for: mode) else { return }
        store(raw, for: mode)
    }

    private static func key(for mode: ToolbarMode) -> String {
        switch mode {
        case .browsing: "ToolbarArrangement.Browsing.V1"
        case .reading: "ToolbarArrangement.Reading.V1"
        }
    }

    private func storedArrangement(for mode: ToolbarMode) -> [String]? {
        defaults.array(forKey: Self.key(for: mode)) as? [String]
    }

    private func store(_ raw: [String], for mode: ToolbarMode) {
        defaults.set(raw, forKey: Self.key(for: mode))
    }
}
