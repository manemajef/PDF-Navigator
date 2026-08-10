import SwiftUI

struct LibraryGridView: View {
    private static let minimumCardWidth: CGFloat = 130
    private static let spacing: CGFloat = 14
    private static let collapsedRowCount = 2

    let recentURLs: [URL]
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let emptyMessage: String
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

    @State private var recentsExpanded = false
    @State private var columnCount = 1

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.minimumCardWidth), spacing: Self.spacing)]
    }

    private var collapsedRecentCount: Int {
        columnCount * Self.collapsedRowCount
    }

    private var visibleRecentURLs: [URL] {
        recentsExpanded
            ? recentURLs
            : Array(recentURLs.prefix(collapsedRecentCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if recentURLs.isEmpty && folderURLs.isEmpty && pdfURLs.isEmpty {
                emptyState
            } else {
                if !recentURLs.isEmpty {
                    recentsSection
                }
                if !folderURLs.isEmpty {
                    foldersSection
                }
                if !pdfURLs.isEmpty {
                    pdfSection
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

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Recents", count: recentURLs.count)
                Spacer()

                if recentURLs.count > collapsedRecentCount {
                    Button(recentsExpanded ? "Show Less" : "Show All") {
                        recentsExpanded.toggle()
                    }
                    .buttonStyle(.link)
                }
            }

            fileGrid(visibleRecentURLs)
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Folders", count: folderURLs.count)

            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: Self.spacing
            ) {
                ForEach(folderURLs, id: \.self) { url in
                    FolderStackView(url: url) {
                        onSelectFolder(url)
                    }
                }
            }
        }
    }

    private var pdfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PDFs", count: pdfURLs.count)
            fileGrid(pdfURLs)
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("(\(count))")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    private func fileGrid(_ urls: [URL]) -> some View {
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: Self.spacing
        ) {
            ForEach(urls, id: \.self) { url in
                FileCardView(
                    url: url,
                    subtitle: url.deletingLastPathComponent().lastPathComponent
                ) {
                    onSelectPDF(url)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(emptyMessage)
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
#Preview("Library Grid") {
    ScrollView {
        LibraryGridView(
            recentURLs: DevelopmentConfiguration.loadPDFs(limit: 12),
            folderURLs: DevelopmentConfiguration.demoFolderURLs,
            pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
            emptyMessage: "This workspace is empty",
            onSelectPDF: { _ in },
            onSelectFolder: { _ in }
        )
        .padding(28)
    }
    .frame(width: 700, height: 620)
}
#endif
