import SwiftUI

/// SwiftUI chrome hosted below the native AppKit navigator.
struct SidebarFooterView: View {
    let itemCount: Int?
    let onOpenInFinder: () -> Void

    init(
        itemCount: Int? = nil,
        onOpenInFinder: @escaping () -> Void = {}
    ) {
        self.itemCount = itemCount
        self.onOpenInFinder = onOpenInFinder
    }

    var body: some View {
        HStack(spacing: 8) {
            if let itemCount {
                Text("\(itemCount) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Workspace")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: onOpenInFinder) {
                Image(systemName: "macwindow.and.cursorarrow")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

#Preview("Sidebar Footer View") {
    VStack(spacing: 8) {
        SidebarFooterView(itemCount: 14)
        SidebarFooterView(itemCount: nil)
    }
    .frame(width: 220)
}
