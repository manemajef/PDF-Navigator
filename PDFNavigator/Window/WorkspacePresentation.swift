import Observation
import SwiftUI

@MainActor
@Observable
final class WorkspacePresentation {
    var columnVisibility: NavigationSplitViewVisibility = .all
    var isSearchPresented = false

    func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }
}
