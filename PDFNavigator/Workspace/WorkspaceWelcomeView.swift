import SwiftUI

struct WorkspaceWelcomeView: View {
    let workspaceName: String
    let hasWorkspace: Bool
    let recentPDFs: [URL]
    let workspaceRecentPDFs: [URL]
    let onOpenRecentPDF: (URL) -> Void
    let onLoadNewWorkspace: () -> Void

    @State private var recentScope = RecentScope.all

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("PDF Navigator")
                    .font(.largeTitle)

                Text("Open a recent PDF or choose a workspace.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                if hasWorkspace {
                    Button {
                        recentScope = .workspace
                    } label: {
                        Label("Stay in \(workspaceName)", systemImage: "folder")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: onLoadNewWorkspace) {
                    Label("Open New…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }

            recentList
                .frame(maxWidth: 440)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var recentList: some View {
        GroupBox {
            if displayedRecentPDFs.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(displayedRecentPDFs, id: \.self) { pdf in
                        Button {
                            onOpenRecentPDF(pdf)
                        } label: {
                            Label(pdf.lastPathComponent, systemImage: "doc")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)

                        if pdf != displayedRecentPDFs.last {
                            Divider()
                        }
                    }
                }
            }
        } label: {
            Text(recentListTitle)
        }
    }

    private var displayedRecentPDFs: [URL] {
        switch recentScope {
        case .all:
            recentPDFs
        case .workspace:
            workspaceRecentPDFs
        }
    }

    private var recentListTitle: String {
        switch recentScope {
        case .all:
            "Recent PDFs"
        case .workspace:
            "Recent in \(workspaceName)"
        }
    }

    private var emptyMessage: String {
        switch recentScope {
        case .all:
            "No recent PDFs."
        case .workspace:
            "No recent PDFs in this workspace."
        }
    }

    private enum RecentScope {
        case all
        case workspace
    }
}

struct WorkspaceEmptyView: View {
    let onOpenWorkspace: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Workspace Open", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Choose a folder or PDF to begin.")
        } actions: {
            Button("Open Workspace", action: onOpenWorkspace)
                .buttonStyle(.borderedProminent)
        }
    }
}
