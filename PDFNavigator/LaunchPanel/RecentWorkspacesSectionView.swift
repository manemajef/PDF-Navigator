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
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Workspaces")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 2) {
                if folderURLs.isEmpty {
                    Text("No recent workspaces.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(folderURLs, id: \.self) { url in
                        RecentRowView(
                            title: url.lastPathComponent,
                            subtitle: url.deletingLastPathComponent().lastPathComponent,
                            iconName: "folder",
                            action: { onSelectFolder(url) }
                        )
                    }
                }
            }
            .padding(6)
//            .background(
//                RoundedRectangle(cornerRadius: 10, style: .continuous)
//                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 10, style: .continuous)
//                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
//            )
        }
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
