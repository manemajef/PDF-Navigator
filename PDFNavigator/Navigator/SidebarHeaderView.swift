import SwiftUI

/// Temporarily disconnected SwiftUI header candidate for the AppKit navigator.
struct SidebarHeaderView: View {
    let title: String
    let isSearchEnabled: Bool
    let onSearch: () -> Void

    init(
        title: String = "Workspace",
        isSearchEnabled: Bool = true,
        onSearch: @escaping () -> Void = {}
    ) {
        self.title = title
        self.isSearchEnabled = isSearchEnabled
        self.onSearch = onSearch
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!isSearchEnabled)
            .help("Search in PDF (Cmd+F)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview("Sidebar Header View") {
    VStack(spacing: 8) {
        SidebarHeaderView(title: "Micro 3", isSearchEnabled: true)
        SidebarHeaderView(title: "Workspace", isSearchEnabled: false)
    }
    .frame(width: 220)
}
