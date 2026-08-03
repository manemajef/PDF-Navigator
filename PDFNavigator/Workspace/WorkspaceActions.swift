import Foundation

/// App-level actions available throughout one workspace window.
final class WorkspaceActions {
    var chooseWorkspace: () -> Void = {}
    var openPDF: (URL) -> Void = { _ in }
    var openInNewTab: (URL) -> Void = { _ in }
    var newTab: () -> Void = {}
}
