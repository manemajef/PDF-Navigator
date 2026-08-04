import SwiftUI

struct LaunchPanelView: View {
    let recentWorkspaces: [URL]
    let recentPDFs: [URL]
    let onOpen: () -> Void
    let onSelectWorkspace: (URL) -> Void
    let onSelectPDF: (URL) -> Void

    init(
        recentWorkspaces: [URL] = [],
        recentPDFs: [URL] = [],
        onOpen: @escaping () -> Void = {},
        onSelectWorkspace: @escaping (URL) -> Void = { _ in },
        onSelectPDF: @escaping (URL) -> Void = { _ in }
    ) {
        self.recentWorkspaces = recentWorkspaces
        self.recentPDFs = recentPDFs
        self.onOpen = onOpen
        self.onSelectWorkspace = onSelectWorkspace
        self.onSelectPDF = onSelectPDF
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LaunchPanelHeaderView(onOpen: onOpen)

                if !recentWorkspaces.isEmpty {
                    RecentWorkspacesSectionView(
                        folderURLs: recentWorkspaces,
                        onSelectFolder: onSelectWorkspace
                    )
                }

                if !recentPDFs.isEmpty {
                    RecentPDFsSectionView(
                        pdfURLs: recentPDFs,
                        onSelectPDF: onSelectPDF
                    )
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 540, minHeight: 520)
    }
}

#Preview("Launch Panel View") {
    LaunchPanelView(
        recentWorkspaces: [
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3"),
            URL(fileURLWithPath: "/Users/demo/Documents/Linear Algebra"),
            URL(fileURLWithPath: "/Users/demo/Documents/Exams")
        ],
        recentPDFs: [
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3/syllabus.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/Linear Algebra/notes.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/lease.pdf")
        ]
    )
}
