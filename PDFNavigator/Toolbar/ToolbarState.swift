import Foundation

/// Everything the toolbar needs to know, as one immutable value.
///
/// `WindowController` derives a fresh value from the session and the reader on
/// every change and hands it to `ToolbarController.render(_:)`. The toolbar
/// stores none of it.
struct ToolbarState {
    let hasPDF: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let isActualSizeActive: Bool

    /// The panel the inspector is showing, or `nil` when it is collapsed.
    ///
    /// One optional, not a `Bool` plus a section: "collapsed, but showing the
    /// outline" is unrepresentable, so nothing downstream handles it.
    let inspectorSection: PDFInspectorSection?
}
