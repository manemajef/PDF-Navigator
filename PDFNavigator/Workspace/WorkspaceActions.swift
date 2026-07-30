import SwiftUI

struct WorkspaceActions {
    let session: WorkspaceSession
    let reader: PDFReaderHandle
    let canCreateTab: Bool
    let createTab: () -> Void
    let replaceWorkspace: () -> Void
    let toggleToolbar: () -> Void
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
