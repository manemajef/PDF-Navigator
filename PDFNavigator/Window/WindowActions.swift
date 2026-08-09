import Foundation

/// Framework-neutral intents that workspace content may send to the AppKit shell.
///
/// AppKit creates this value and SwiftUI receives it through an initializer.
/// It must never expose an `NSWindow`, view, controller, or responder.
struct WindowActions {
    let chooseLocation: () -> Void
    let openInNewTab: (URL, TabActivation) -> Void
    let revealInFinder: (URL) -> Void
    let beginSearch: () -> Void
}
