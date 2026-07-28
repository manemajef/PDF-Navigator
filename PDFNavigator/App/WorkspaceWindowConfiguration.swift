import Foundation

struct WorkspaceWindowConfiguration: Codable, Hashable {
    let id: UUID
    let workspaceURL: URL?
    let selectedPDF: URL?
    let lastSelectedPDF: URL?
    let sourceWindowNumber: Int?
    let presentsWorkspacePicker: Bool?
    let startsAtWelcome: Bool?

    static func newWorkspaceTab(
        workspaceURL: URL?,
        lastSelectedPDF: URL?,
        sourceWindowNumber: Int
    ) -> WorkspaceWindowConfiguration {
        WorkspaceWindowConfiguration(
            id: UUID(),
            workspaceURL: workspaceURL,
            selectedPDF: nil,
            lastSelectedPDF: lastSelectedPDF,
            sourceWindowNumber: sourceWindowNumber,
            presentsWorkspacePicker: false,
            startsAtWelcome: true
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
            lastSelectedPDF: nil,
            sourceWindowNumber: sourceWindowNumber,
            presentsWorkspacePicker: false,
            startsAtWelcome: false
        )
    }
}
