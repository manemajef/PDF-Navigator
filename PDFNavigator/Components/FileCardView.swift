import SwiftUI

struct FileCardView: View {
    let title: String
    let subtitle: String?
    let iconName: String
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        iconName: String = "doc.text.fill",
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.hover(cornerRadius: 10))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview("File Card View") {
    VStack(spacing: 10) {
        FileCardView(
            title: "micro3-syllabus.pdf",
            subtitle: "Opened 2h ago"
        )
        FileCardView(
            title: "a-very-long-paper-title-that-should-truncate-in-the-middle.pdf",
            subtitle: "Opened yesterday"
        )
    }
    .padding(20)
    .frame(width: 320)
}
