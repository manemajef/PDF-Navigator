import SwiftUI

struct LaunchPanelHeaderView: View {
    let showingWorkspaces: Bool
    let onOpen: () -> Void
    let onToggleShowingWorkspaces: () -> Void

    init(
        showingWorkspaces: Bool = true,
        onOpen: @escaping () -> Void = {},
        onToggleShowingWorkspaces: @escaping () -> Void = {}
    ) {
        self.showingWorkspaces = showingWorkspaces
        self.onOpen = onOpen
        self.onToggleShowingWorkspaces = onToggleShowingWorkspaces
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("PDF Navigator")
                    .font(.system(size: 26, weight: .bold))

                Text("Open a PDF or folder workspace to get started.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                Button("Open New", action: onOpen)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button(
                    showingWorkspaces ? "Show Recent PDFs" : "Show Recent Workspaces",
                    action: onToggleShowingWorkspaces
                )
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 6)
        }
    }
}

#Preview("Launch Panel Header View") {
    LaunchPanelHeaderView()
        .padding(24)
        .frame(width: 440)
}
