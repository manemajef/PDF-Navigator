import SwiftUI

struct SidebarHeaderView: View {
    let title: String
    let onSearch: () -> Void

    init(
        title: String = "Workspace",
        onSearch: @escaping () -> Void = {}
    ) {
        self.title = title
        self.onSearch = onSearch
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sidebar.left")
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Search in PDF (Cmd+F)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

#Preview("Sidebar Header View") {
    VStack {
        SidebarHeaderView(title: "Micro 3")
        SidebarHeaderView(title: "Linear Algebra Workspace")
    }
    .frame(width: 220)
}
