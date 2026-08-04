import SwiftUI

struct FolderCardView: View {
    let name: String
    let subtitle: String?
    let action: () -> Void

    init(
        name: String,
        subtitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.name = name
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.accentColor.gradient)

                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .top)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 100)
        }
        .buttonStyle(.hover(cornerRadius: 10))
    }
}

#Preview("Folder Card View") {
    HStack(spacing: 12) {
        FolderCardView(name: "Micro 3", subtitle: "2h ago")
        FolderCardView(name: "Problem Sets", subtitle: "Yesterday")
        FolderCardView(name: "Linear Algebra Exam Notes", subtitle: "3d ago")
    }
    .padding(20)
}
