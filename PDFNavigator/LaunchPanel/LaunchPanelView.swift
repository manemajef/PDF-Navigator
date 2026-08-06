import SwiftUI

struct LaunchPanelView: View {
    let recentWorkspaces: [URL]
    let recentPDFs: [URL]

    let onOpen: () -> Void
    let onSelectWorkspace: (URL) -> Void
    let onSelectPDF: (URL) -> Void

    @State private var showingWorkspaces = true

    var body: some View {
        HStack(spacing: 0) {
            mainContent

            Divider()

            recentItemsColumn
        }
        .frame(width: 680, height: 420)
    }

    // MARK: - Main launch area

    private var mainContent: some View {
        VStack {
            Spacer()

            LaunchPanelHeaderView(
                showingWorkspaces: showingWorkspaces,
                onOpen: onOpen,
                onToggleShowingWorkspaces: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingWorkspaces.toggle()
                    }
                }
            )

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Recent items

    private var recentItemsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showingWorkspaces {
                    RecentWorkspacesSectionView(
                        folderURLs: recentWorkspaces,
                        onSelectFolder: onSelectWorkspace
                    )
                } else {
                    RecentPDFsSectionView(
                        pdfURLs: recentPDFs,
                        onSelectPDF: onSelectPDF
                    )
                }
            }
            .padding(16)
        }
        .frame(width: 290)
        .frame(maxHeight: .infinity)
        .background(.thinMaterial)
    }
}

// MARK: - Preview

#Preview("Launch Panel") {
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
        ],
        onOpen: {
            print("Open workspace")
        },
        onSelectWorkspace: { url in
            print("Selected workspace:", url.path)
        },
        onSelectPDF: { url in
            print("Selected PDF:", url.path)
        }
    )
}
