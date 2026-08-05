import SwiftUI

struct LaunchPanelView: View {
    let recentWorkspaces: [URL]
    let recentPDFs: [URL]

    let onOpen: () -> Void
    let onSelectWorkspace: (URL) -> Void
    let onSelectPDF: (URL) -> Void

    var body: some View {
        HStack(spacing: 0) {
            mainContent

            Divider()

            recentPDFsColumn
        }
        .frame(width: 820, height: 520)
    }

    // MARK: - Main launch area

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                LaunchPanelHeaderView(
                    onOpen: onOpen
                )

                if !recentWorkspaces.isEmpty {
                    RecentWorkspacesSectionView(
                        folderURLs: recentWorkspaces,
                        onSelectFolder: onSelectWorkspace
                    )
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
            .frame(
                maxWidth: .infinity,
                minHeight: 520,
                alignment: .top
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Recent PDFs

    private var recentPDFsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if recentPDFs.isEmpty {
                    Text("No Recent PDFs")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 80
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
