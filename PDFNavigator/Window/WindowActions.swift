import Foundation

enum TabActivation {
    case foreground
    case background
}

/// Mutable installation point used only while AppDelegate wires a new window.
final class WindowActions {
    var chooseLocation: () -> Void = {}
    var openPDF: (URL) -> Void = { _ in }
    var openInNewTab: (URL, TabActivation) -> Void = { _, _ in }
    var newTab: (TabActivation) -> Void = { _ in }
}

/// Immutable operations available to the SwiftUI tree for one native tab.
struct WindowCommands {
    let chooseLocation: () -> Void
    let openPDF: (URL) -> Void
    let openInNewTab: (URL, TabActivation) -> Void
    let newTab: (TabActivation) -> Void
    let revealInFinder: (URL) -> Void

    let goToPreviousPage: () -> Void
    let goToNextPage: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let showActualSize: () -> Void
    let zoomToFit: () -> Void
    let openCurrentPDFInDefaultApp: () -> Void
    let shareCurrentPDF: () -> Void

    static let preview = WindowCommands(
        chooseLocation: {},
        openPDF: { _ in },
        openInNewTab: { _, _ in },
        newTab: { _ in },
        revealInFinder: { _ in },
        goToPreviousPage: {},
        goToNextPage: {},
        zoomIn: {},
        zoomOut: {},
        showActualSize: {},
        zoomToFit: {},
        openCurrentPDFInDefaultApp: {},
        shareCurrentPDF: {}
    )
}
