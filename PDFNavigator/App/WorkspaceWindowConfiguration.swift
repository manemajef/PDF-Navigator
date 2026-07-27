import Foundation

struct WorkspaceWindowConfiguration: Codable, Hashable {
    let id: UUID
    let workspaceURL: URL?
    let selectedPDF: URL?
    let sourceWindowNumber: Int?
    let presentsWorkspacePicker: Bool?

    static func newWorkspaceTab(
        sourceWindowNumber: Int
    ) -> WorkspaceWindowConfiguration {
        WorkspaceWindowConfiguration(
            id: UUID(),
            workspaceURL: nil,
            selectedPDF: nil,
            sourceWindowNumber: sourceWindowNumber,
            presentsWorkspacePicker: true
        )
    }

    static func duplicateTab(
        workspaceURL: URL,
        selectedPDF: URL,
        sourceWindowNumber: Int
    ) -> WorkspaceWindowConfiguration {
        WorkspaceWindowConfiguration(
            id: UUID(),
            workspaceURL: workspaceURL,
            selectedPDF: selectedPDF,
            sourceWindowNumber: sourceWindowNumber,
            presentsWorkspacePicker: false
        )
    }
}
