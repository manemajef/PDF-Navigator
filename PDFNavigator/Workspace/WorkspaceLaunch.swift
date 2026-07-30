import Foundation

struct WorkspaceLaunch: Codable, Hashable {
    let id: UUID
    let rootURL: URL?
    let selectedPDF: URL?
    let lastSelectedPDF: URL?
    let presentsPicker: Bool
    let startsAtWelcome: Bool

    static var emptyWindow: WorkspaceLaunch {
        WorkspaceLaunch(
            id: UUID(),
            rootURL: nil,
            selectedPDF: nil,
            lastSelectedPDF: nil,
            presentsPicker: false,
            startsAtWelcome: true
        )
    }

    static func newTab(
        rootURL: URL?,
        lastSelectedPDF: URL?
    ) -> WorkspaceLaunch {
        WorkspaceLaunch(
            id: UUID(),
            rootURL: rootURL,
            selectedPDF: nil,
            lastSelectedPDF: lastSelectedPDF,
            presentsPicker: false,
            startsAtWelcome: true
        )
    }

    static func openingPDF(
        rootURL: URL,
        selectedPDF: URL
    ) -> WorkspaceLaunch {
        WorkspaceLaunch(
            id: UUID(),
            rootURL: rootURL,
            selectedPDF: selectedPDF,
            lastSelectedPDF: nil,
            presentsPicker: false,
            startsAtWelcome: false
        )
    }
}
