import SwiftUI

struct RecentSectionView: View {
    let title: String
    let urls: [URL]
    let iconName: String
    let emptyText: String
    let onSelectURL: (URL) -> Void

    init(
        title: String,
        urls: [URL] = [],
        iconName: String = "doc.text",
        emptyText: String = "No recent items.",
        onSelectURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.title = title
        self.urls = urls
        self.iconName = iconName
        self.emptyText = emptyText
        self.onSelectURL = onSelectURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 2) {
                if urls.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(urls, id: \.self) { url in
                        RecentRowView(
                            title: url.lastPathComponent,
                            subtitle: url.deletingLastPathComponent().lastPathComponent,
                            iconName: iconName,
                            action: { onSelectURL(url) }
                        )
                    }
                }
            }
            .padding(6)
        }
    }
}

#if DEBUG
#Preview("Recent Section") {
    RecentSectionView(
        title: "Recent Workspaces",
        urls: [
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3"),
            URL(fileURLWithPath: "/Users/demo/Documents/Linear Algebra")
        ],
        iconName: "folder",
        emptyText: "No recent workspaces."
    )
    .padding(20)
}
#endif
