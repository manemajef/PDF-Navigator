import SwiftUI

struct WorkspaceWelcomeView: View {
    let workspaceName: String
    let lastSelectedPDF: URL?
    let hasWorkspace: Bool
    let onOpenLastPDF: () -> Void
    let onLoadNewWorkspace: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)

            Text("New Tab")
                .font(.title2)

            if hasWorkspace {
                Text(
                    "Choose a PDF from \(workspaceName) in the sidebar."
                )
                .foregroundStyle(.secondary)

                if let lastSelectedPDF {
                    Button(action: onOpenLastPDF) {
                        Label(
                            "Open \(lastSelectedPDF.lastPathComponent)",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .help("Open Last PDF")
                }
            } else {
                Text("Choose a workspace to begin.")
                    .foregroundStyle(.secondary)
            }

            Button(
                "Load New Workspace…",
                action: onLoadNewWorkspace
            )
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WorkspaceEmptyView: View {
    let onOpenWorkspace: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                "No Workspace Open",
                systemImage: "doc.text.magnifyingglass"
            )
        } description: {
            Text("Choose a folder or PDF to begin.")
        } actions: {
            Button(
                "Open Workspace",
                action: onOpenWorkspace
            )
            .buttonStyle(.borderedProminent)
        }
    }
}
