import SwiftUI

struct LibraryGridView: View {
    private static let minimumCardWidth: CGFloat = 130
    private static let spacing: CGFloat = 14

    let folderURLs: [URL]
    let pdfURLs: [URL]
    let emptyMessage: String
    let onOpenPDF: (URL) -> Void
    let onOpenFolder: (URL) -> Void
    
    @State private var selectedURL: URL?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.minimumCardWidth), spacing: Self.spacing)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if folderURLs.isEmpty && pdfURLs.isEmpty {
                emptyState
            } else {
                if !folderURLs.isEmpty {
                    foldersSection
                }
                if !pdfURLs.isEmpty {
                    pdfSection
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Behind the items, so hit-testing sends a press to the item's catcher
        // when there is one and to this one otherwise. A SwiftUI gesture here
        // would instead fire *as well as* the item's, clearing the selection
        // the same click just made.
        .background(ClickCatcher { _ in selectedURL = nil })
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
                    FolderCardView(
                        url: url,
                        isSelected: selectedURL == url,
                        onSelect: { selectedURL = url },
                        onOpen: { onOpenFolder(url) }
                    )
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
                    subtitle: url.deletingLastPathComponent().lastPathComponent,
                    isSelected: selectedURL == url,
                    onSelect: { selectedURL = url },
                    onOpen: { onOpenPDF(url) }
                )
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
/// Enough items to see wrapping, row rhythm, and scrolling. The root folder
/// alone yields four folders and two PDFs, which is too few to judge any of it.
private enum GridPreviewData {
    static let folderURLs: [URL] =
        DevelopmentConfiguration.demoFolderURLs
        + [DevelopmentConfiguration.demoLongNameFolderURL]

    static let pdfURLs: [URL] =
        DevelopmentConfiguration.loadPDFs(limit: 40)
}

#Preview("Library Grid — populated") {
    ScrollView {
        LibraryGridView(
            folderURLs: GridPreviewData.folderURLs,
            pdfURLs: GridPreviewData.pdfURLs,
            emptyMessage: "This workspace is empty",
            onOpenPDF: { _ in },
            onOpenFolder: { _ in }
        )
        .padding(28)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .frame(width: 900, height: 700)
}

#Preview("Library Grid — narrow") {
    ScrollView {
        LibraryGridView(
            folderURLs: GridPreviewData.folderURLs,
            pdfURLs: GridPreviewData.pdfURLs,
            emptyMessage: "This workspace is empty",
            onOpenPDF: { _ in },
            onOpenFolder: { _ in }
        )
        .padding(28)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .frame(width: 380, height: 700)
}

#Preview("Library Grid — empty") {
    LibraryGridView(
        folderURLs: [],
        pdfURLs: [],
        emptyMessage: "This workspace is empty",
        onOpenPDF: { _ in },
        onOpenFolder: { _ in }
    )
    .padding(28)
    .frame(width: 700, height: 300)
}
#endif
