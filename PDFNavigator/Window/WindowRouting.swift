import Foundation

enum TabActivation {
    case foreground
    case background
}

/// AppKit-only callbacks installed by `AppDelegate` for one workspace window.
final class WindowRouting {
    var chooseLocation: () -> Void = {}
    var openInNewTab: (URL, TabActivation) -> Void = { _, _ in }
    var newTab: (TabActivation) -> Void = { _ in }
}
