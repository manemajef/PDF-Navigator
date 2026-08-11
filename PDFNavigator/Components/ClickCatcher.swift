import AppKit
import SwiftUI

/// Reports every press with the click count AppKit resolved for it.
///
/// `TapGesture(count:)` infers a double click from timing, so it must wait out
/// the system double-click interval before it can report a single one.
/// `NSEvent.clickCount` is the value AppKit's own controls read; the window
/// server has already decided it by the time the event arrives.
///
/// Use this for *every* click in a region, not just some of them. SwiftUI
/// gestures and embedded `NSView`s are separate event layers and both fire for
/// the same press, so mixing them makes one click run two handlers. Where these
/// views overlap, hit-testing picks the frontmost one and only that one runs.
struct ClickCatcher: NSViewRepresentable {
    let onClick: (Int) -> Void

    func makeNSView(context: Context) -> ClickCatchingView {
        ClickCatchingView(onClick: onClick)
    }

    func updateNSView(_ nsView: ClickCatchingView, context: Context) {
        // Reassigned rather than rebuilt: the same view has to stay in place
        // between the two presses of a double click.
        nsView.onClick = onClick
    }
}

final class ClickCatchingView: NSView {
    var onClick: (Int) -> Void

    init(onClick: @escaping (Int) -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    /// The first click into an inactive window acts, rather than being spent
    /// activating it — which is how Finder behaves.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onClick(event.clickCount)
    }
}
