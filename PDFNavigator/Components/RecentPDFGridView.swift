import SwiftUI

/// The workspace-scoped Recents section shown on a new tab's Start Page.
struct RecentPDFGridView: View {
    private static let minimumCardWidth: CGFloat = 130
    private static let spacing: CGFloat = 14
    private static let collapsedRowCount = 2

    let urls: [URL]
    let onOpenPDF: (URL) -> Void

    @State private var isExpanded = false
    @State private var columnCount = 1
    @State private var selectedURL: URL?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.minimumCardWidth), spacing: Self.spacing)]
    }

    private var collapsedCount: Int {
        columnCount * Self.collapsedRowCount
    }

    private var visibleURLs: [URL] {
        isExpanded ? urls : Array(urls.prefix(collapsedCount))
    }

    var body: some View {
        if urls.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle
                    Spacer()

                    if urls.count > collapsedCount {
                        Button(isExpanded ? "Show Less" : "Show All") {
                            isExpanded.toggle()
                        }
                        .buttonStyle(.link)
                    }
                }

                LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: Self.spacing
                ) {
                    ForEach(visibleURLs, id: \.self) { url in
                        FileCardView(
                            url: url,
                            subtitle: url.deletingLastPathComponent().lastPathComponent,
                            isSelected: selectedURL == url,
                            onSelect: {selectedURL = url},
                            onOpen: {onOpenPDF(url)}
                        )
                    }
                }
            }
            .onGeometryChange(for: Int.self) { proxy in
                max(
                    1,
                    Int((proxy.size.width + Self.spacing)
                        / (Self.minimumCardWidth + Self.spacing))
                )
            } action: { columnCount = $0 }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedURL = nil
            }
                
        }
    }

    private var sectionTitle: some View {
        HStack(spacing: 6) {
            Text("Recents")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("(\(urls.count))")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No recent PDFs in this workspace")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        )
    }
}

#if DEBUG
#Preview("Recent PDFs") {
    ScrollView {
        RecentPDFGridView(
            urls: DevelopmentConfiguration.loadPDFs(limit: 12),
            onOpenPDF: { _ in }
        )
        .padding(28)
    }
    .frame(width: 700, height: 620)
}
#endif
