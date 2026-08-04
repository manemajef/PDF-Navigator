import SwiftUI

struct RecentWorkspacesSectionView: View {
    let folderURLs: [URL]
    let onSelectFolder: (URL) -> Void

    init(
        folderURLs: [URL] = [],
        onSelectFolder: @escaping (URL) -> Void = { _ in }
    ) {
        self.folderURLs = folderURLs
        self.onSelectFolder = onSelectFolder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Workspaces")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            if folderURLs.isEmpty {
                Text("No recent workspaces.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(folderURLs, id: \.self) { url in
                            FolderCardView(
                                name: url.lastPathComponent,
                                subtitle: url.deletingLastPathComponent().lastPathComponent,
                                action: { onSelectFolder(url) }
                            )
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(maxWidth: 460)
    }
}

#Preview("Recent Workspaces Section") {
    RecentWorkspacesSectionView(
        folderURLs: [
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3"),
            URL(fileURLWithPath: "/Users/demo/Documents/Linear Algebra"),
            URL(fileURLWithPath: "/Users/demo/Documents/Problem Sets")
        ]
    )
    .padding(20)
}
