import SwiftUI

struct WorkspaceActions {
    let session: WorkspaceSession
    let reader: PDFReaderHandle
    let canCreateTab: Bool
    let hasMultipleTabs: Bool 
    let createTab: () -> Void
    let duplicateTab: () -> Void
    let replaceWorkspace: () -> Void
    let toggleToolbar: () -> Void

    var canDuplicateTab: Bool {
        canCreateTab && session.rootURL != nil && session.selectedPDF != nil
    }
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
