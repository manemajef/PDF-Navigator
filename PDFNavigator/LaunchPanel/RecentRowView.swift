import SwiftUI

struct RecentRowView: View {
    let title: String
    let subtitle: String?
    let timestamp: String?
    let iconName: String
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        timestamp: String? = nil,
        iconName: String = "doc.text",
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.iconName = iconName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .truncationMode(.middle)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                if let timestamp {
                    Text(timestamp)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Recent Row View") {
    VStack(spacing: 4) {
        RecentRowView(
            title: "micro3-syllabus.pdf",
            subtitle: "University/Micro 3",
            timestamp: "2h ago"
        )
        RecentRowView(
            title: "linear-algebra-notes.pdf",
            subtitle: "University/Linear Algebra",
            timestamp: "yesterday"
        )
    }
    .padding(12)
    .frame(width: 400)
}
#endif
