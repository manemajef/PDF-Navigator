import AppKit

/// A source list that resolves command-click before selection runs.
///
/// Command-clicking a PDF opens a background tab and must not move the
/// selection. Handling it in the event layer keeps the delegate methods free of
/// modifier checks, which only work for mouse input and misbehave for keyboard
/// and accessibility-driven selection.
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
