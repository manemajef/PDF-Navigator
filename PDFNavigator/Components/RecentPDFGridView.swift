import SwiftUI

/// The workspace-scoped Recents section shown on a new tab's Start Page.
///
/// Still a `LazyVGrid`, so it has no selection — a grid is a layout, not a
/// control, and selection here would mean re-implementing one. The library
/// moved to `GalleryController` for that reason; this surface is the next
/// candidate, once the Show All affordance has a home in a collection view.
struct RecentPDFGridView: View {
    private static let minimumCardWidth: CGFloat = 130
    private static let spacing: CGFloat = 14
    private static let collapsedRowCount = 2

    let urls: [URL]
    let onOpenPDF: (URL) -> Void

    @State private var isExpanded = false
    @State private var columnCount = 1

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
            GalleryEmptyState(
                symbolName: "clock",
                message: "No recent PDFs in this workspace"
            )
            .frame(minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GallerySectionHeader(title: "Recents", count: urls.count)

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
                            isSelected: false
                        )
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onOpenPDF(url) }
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
        }
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
