import AppKit

/// A source list that resolves command-click before selection runs.
///
/// Command-clicking a PDF opens it in a background tab and must not move the
/// selection. Detecting that inside `shouldSelectItem` or
/// `selectionDidChange` — by reaching for `NSApp.currentEvent` — reads the
/// modifier through a side channel that only exists for mouse input, and so
/// misbehaves for keyboard and accessibility-driven selection.
///
/// Handling it here, in the event layer, means the delegate methods never see a
/// modifier at all: they answer only "is this row selectable" and "the selection
/// moved", which is what they are actually for.
final class NavigatorOutlineView: NSOutlineView {
    /// Returns `true` when the click was consumed and selection should not run.
    var onCommandClick: ((Int) -> Bool)?

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let clicked = row(at: point)
        guard clicked >= 0, onCommandClick?(clicked) == true else {
            super.mouseDown(with: event)
            return
        }
    }
}
