import SwiftUI

struct SidebarItemRowView: View {
    let title: String
    let isDirectory: Bool
    let isExpanded: Bool
    let isSelected: Bool
    let level: Int
    let onToggleExpand: () -> Void
    let onSelect: () -> Void

    init(
        title: String,
        isDirectory: Bool,
        isExpanded: Bool = false,
        isSelected: Bool = false,
        level: Int = 0,
        onToggleExpand: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.title = title
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.isSelected = isSelected
        self.level = level
        self.onToggleExpand = onToggleExpand
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 6) {
            // Indentation
            Spacer()
                .frame(width: CGFloat(level * 12))

            // Expand chevron for directories
            if isDirectory {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 12)
            }

            // File / Folder icon
            Image(systemName: isDirectory ? "folder.fill" : "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(isDirectory ? Color.accentColor : Color.secondary)

            // Title
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview("Sidebar Item Row View") {
    VStack(spacing: 2) {
        SidebarItemRowView(
            title: "Problem Sets",
            isDirectory: true,
            isExpanded: true,
            isSelected: false,
            level: 0
        )
        SidebarItemRowView(
            title: "problem-set-1.pdf",
            isDirectory: false,
            isSelected: true,
            level: 1
        )
        SidebarItemRowView(
            title: "problem-set-2.pdf",
            isDirectory: false,
            isSelected: false,
            level: 1
        )
    }
    .padding(12)
    .frame(width: 240)
}
