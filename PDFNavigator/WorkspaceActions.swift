import SwiftUI

struct WorkspaceActions {
    let canGoBack: Bool
    let canGoForward: Bool
    let canCreateWorkspaceTab: Bool
    let canDuplicateTab: Bool

    let goBack: () -> Void
    let goForward: () -> Void
    let createWorkspaceTab: () -> Void
    let duplicateTab: () -> Void
    let reader: PDFReaderActions
}

struct PDFReaderActions {
    let capabilities: PDFReaderCapabilities
    let goToPreviousPage: () -> Void
    let goToNextPage: () -> Void
    let goBack: () -> Void
    let goForward: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let showActualSize: () -> Void
    let zoomToFit: () -> Void
}

private struct WorkspaceActionsKey: FocusedValueKey {
    typealias Value = WorkspaceActions
}

extension FocusedValues {
    var workspaceActions: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}
