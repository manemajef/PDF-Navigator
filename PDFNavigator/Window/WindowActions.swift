import Foundation

/// App-level actions available throughout one native tab or window.
final class WindowActions {
    var chooseLocation: () -> Void = {}
    var openPDF: (URL) -> Void = { _ in }
    var openInNewTab: (URL) -> Void = { _ in }
    var newTab: () -> Void = {}
}
