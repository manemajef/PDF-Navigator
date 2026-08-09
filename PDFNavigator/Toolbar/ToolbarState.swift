import Foundation

/// Everything the toolbar needs to know, as one immutable value.
///
/// The toolbar stores none of this. `WindowController` derives a fresh value
/// from the session and the reader whenever something changes and hands it to
/// `ToolbarController.render(_:)`. A toolbar that remembers nothing cannot be out
/// of date, and adding a toolbar item never means finding the place that
/// refreshes it.
struct ToolbarState {
    let hasPDF: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let isActualSizeActive: Bool

    /// The panel the inspector is showing, or `nil` when it is collapsed.
    ///
    /// One optional rather than a `Bool` alongside a section: "collapsed, but
    /// showing the outline" is not a state this type can express, so nothing
    /// downstream has to handle it.
    let inspectorSection: PDFInspectorSection?
}
