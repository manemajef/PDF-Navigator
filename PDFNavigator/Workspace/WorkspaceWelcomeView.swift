import SwiftUI

struct WorkspaceWelcomeView: View {
    let recentPDFs: [URL]
    let onOpenRecentPDF: (URL) -> Void
    let onLoadNewWorkspace: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)

            Text("PDF Navigator")
                .font(.largeTitle)

            Button(action: onLoadNewWorkspace) {
                Label("Open New", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            GroupBox("Recent PDFs") {
                if recentPDFs.isEmpty {
                    Text("No recent PDFs.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recentPDFs, id: \.self) { pdf in
                            Button {
                                onOpenRecentPDF(pdf)
                            } label: {
                                Label(
                                    pdf.lastPathComponent,
                                    systemImage: "doc"
                                )
                                .lineLimit(1)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 6)

                            if pdf != recentPDFs.last {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 440)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
