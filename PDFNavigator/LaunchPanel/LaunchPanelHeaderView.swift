import SwiftUI

struct LaunchPanelHeaderView: View {
    let onOpen: () -> Void

    init(onOpen: @escaping () -> Void = {}) {
        self.onOpen = onOpen
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.secondary)

            Text("PDF Navigator")
                .font(.system(size: 26, weight: .bold))

            Text("Open a PDF or folder workspace to get started.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button("Open…", action: onOpen)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 6)
        }
    }
}

#Preview("Launch Panel Header View") {
    LaunchPanelHeaderView()
        .padding(24)
        .frame(width: 440)
}
