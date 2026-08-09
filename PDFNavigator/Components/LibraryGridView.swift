import SwiftUI

// MARK: - Folder Presentation Mode

/// How folder items are displayed in the library grid.
enum FolderDisplayMode: Sendable, Hashable {
    /// 3D layered document pages stack with circular badge
    case stack
    /// Frosted glass square container with mini-grid of pages (iOS style)
    case card
}

// MARK: - Library Grid View

/// Grid view displaying folder cards and PDF document cards for workspace navigation.
struct LibraryGridView: View {
    let folderURLs: [URL]
    let pdfURLs: [URL]
    let folderMode: FolderDisplayMode
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

    init(
        folderURLs: [URL] = [],
        pdfURLs: [URL] = [],
        folderMode: FolderDisplayMode = .stack,
        onSelectPDF: @escaping (URL) -> Void = { _ in },
        onSelectFolder: @escaping (URL) -> Void = { _ in }
    ) {
        self.folderURLs = folderURLs
        self.pdfURLs = pdfURLs
        self.folderMode = folderMode
        self.onSelectPDF = onSelectPDF
        self.onSelectFolder = onSelectFolder
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
                    recentPDFsSection
                }
            }
        }
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Folders")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("(\(folderURLs.count))")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 14)],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(folderURLs, id: \.self) { url in
                    switch folderMode {
                    case .stack:
                        FolderStackView(
                            url: url,
                            action: { onSelectFolder(url) }
                        )
                    case .card:
                        FolderCardView(
                            url: url,
                            action: { onSelectFolder(url) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Recent PDFs Section

    private var recentPDFsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Recent PDFs")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("(\(pdfURLs.count))")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 14)],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(pdfURLs, id: \.self) { url in
                    FileCardView(
                        url: url,
                        subtitle: url.deletingLastPathComponent().lastPathComponent,
                        action: { onSelectPDF(url) }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No folders or PDFs in this workspace")
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

// MARK: - Backward Compatibility

typealias FileCardGridView = LibraryGridView

// MARK: - Previews

#if DEBUG
#Preview("Library Grid - Stack Mode") {
    ScrollView {
        LibraryGridView(
            folderURLs: DevelopmentConfiguration.demoFolderURLs,
            pdfURLs: DevelopmentConfiguration.loadPDFs(limit: 8),
            folderMode: .stack
        )
        .padding(24)
    }
    .frame(width: 700, height: 600)
}

#Preview("Library Grid - Card Mode (iOS Glass)") {
    ScrollView {
        LibraryGridView(
            folderURLs: DevelopmentConfiguration.demoFolderURLs,
            pdfURLs: DevelopmentConfiguration.loadPDFs(limit: 8),
            folderMode: .card
        )
        .padding(24)
    }
    .frame(width: 700, height: 600)
}

#Preview("Library Grid - Translucent Canvas") {
    ZStack {
        // Vibrant background wallpaper to test glassmorphism
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.14, blue: 0.38),
                Color(red: 0.28, green: 0.18, blue: 0.52),
                Color(red: 0.12, green: 0.32, blue: 0.58),
                Color(red: 0.05, green: 0.12, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        Circle()
            .fill(Color.purple.opacity(0.35))
            .frame(width: 320, height: 320)
            .blur(radius: 60)
            .offset(x: -180, y: -100)

        Circle()
            .fill(Color.cyan.opacity(0.30))
            .frame(width: 300, height: 300)
            .blur(radius: 50)
            .offset(x: 180, y: 120)

        ScrollView {
            LibraryGridView(
                folderURLs: DevelopmentConfiguration.demoFolderURLs,
                pdfURLs: DevelopmentConfiguration.loadPDFs(limit: 8),
                folderMode: .card
            )
            .padding(28)
        }
    }
    .frame(width: 720, height: 620)
}

#Preview("Library Grid - PDFs Only") {
    ScrollView {
        LibraryGridView(
            pdfURLs: DevelopmentConfiguration.loadPDFs(limit: 6)
        )
        .padding(24)
    }
    .frame(width: 650, height: 400)
}

#Preview("Library Grid - Empty") {
    LibraryGridView()
        .padding(24)
        .frame(width: 500, height: 250)
}
#endif
