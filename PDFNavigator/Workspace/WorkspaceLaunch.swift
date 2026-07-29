import Foundation

struct WorkspaceLaunch: Codable, Hashable {
    let id: UUID
    let rootURL: URL?
    let selectedPDF: URL?
    let lastSelectedPDF: URL?
    let sidebarVisible: Bool?
    let presentsPicker: Bool
    let startsAtWelcome: Bool

    static var emptyWindow: WorkspaceLaunch {
        WorkspaceLaunch(
            id: UUID(),
            rootURL: nil,
            selectedPDF: nil,
            lastSelectedPDF: nil,
            sidebarVisible: false,
            presentsPicker: false,
            startsAtWelcome: true
        )
    }

    static func newTab(
        rootURL: URL?,
        lastSelectedPDF: URL?,
        sidebarVisible: Bool
    ) -> WorkspaceLaunch {
        WorkspaceLaunch(
            id: UUID(),
            rootURL: rootURL,
            selectedPDF: nil,
            lastSelectedPDF: lastSelectedPDF,
            sidebarVisible: sidebarVisible,
            presentsPicker: false,
            startsAtWelcome: true
        )
    }

    static func openingPDF(
        rootURL: URL,
        selectedPDF: URL,
        sidebarVisible: Bool = false
    ) -> WorkspaceLaunch {
        WorkspaceLaunch(
            id: UUID(),
            rootURL: rootURL,
            selectedPDF: selectedPDF,
            lastSelectedPDF: nil,
            sidebarVisible: sidebarVisible,
            presentsPicker: false,
            startsAtWelcome: false
        )
    }
}
