import SwiftUI

struct LibraryGridView: View {
    private static let minimumCardWidth: CGFloat = 130
    private static let spacing: CGFloat = 14

    let folderURLs: [URL]
    let pdfURLs: [URL]
    let emptyMessage: String
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

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
//                    FolderCardView(url: url) {
//                        onSelectFolder(url)
//                    }
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
    NavigationSplitView{


    } detail: {
        ScrollView {
            LibraryGridView(
                folderURLs: DevelopmentConfiguration.demoFolderURLs,
                pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
                emptyMessage: "This workspace is empty",
                onSelectPDF: { _ in },
                onSelectFolder: { _ in }
            )
            .padding(28)
        }    /*.frame(width: 700, height: 300)*/
        .toolbar{
            ToolbarItem{
                Button(action: {}){
                    Label("New", systemImage: "plus")
                }
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)



    }

}
#endif
