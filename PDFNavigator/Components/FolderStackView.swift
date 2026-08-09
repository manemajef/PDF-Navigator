import AppKit
import SwiftUI

private let CARD_THUMB_WIDTH: CGFloat = 120.0
private let CARD_THUMB_HEIGHT: CGFloat = CARD_THUMB_WIDTH * 1.4

/// A card representing a folder with a 3D layered stack of child document pages and a floating circular folder badge.
struct FolderStackView: View {
    let url: URL
    let subtitle: String?
    let action: () -> Void

    @State private var contents: FolderContents?

    init(
        url: URL,
        subtitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.url = url.standardizedFileURL
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                pagesStackThumbnail

                VStack(alignment: .leading, spacing: 2) {
                    Text(folderName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(displaySubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: CARD_THUMB_WIDTH, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .task(id: url) {
            loadFolderContents()
        }
    }

    // MARK: - Pages Stack Thumbnail

    private var pagesStackThumbnail: some View {
        let previewPDFs = contents?.previewPDFs ?? []

        return ZStack(alignment: .bottomTrailing) {
            if let firstPDF = previewPDFs.first {
                stackedPDFPreview(
                    primary: firstPDF,
                    secondary: previewPDFs.count > 1 ? previewPDFs[1] : nil,
                    tertiary: previewPDFs.count > 2 ? previewPDFs[2] : nil
                )
            } else {
                emptyFolderPlaceholder
            }

            folderBadge
                .offset(x: 2, y: 2)
        }
        .frame(width: CARD_THUMB_WIDTH, height: CARD_THUMB_HEIGHT)
    }

    @ViewBuilder
    private func stackedPDFPreview(primary: URL, secondary: URL?, tertiary: URL?) -> some View {
        ZStack {
            // Background page (3rd) if available
            if let tertiary {
                ThumbnailView(
                    url: tertiary,
                    size: CGSize(width: CARD_THUMB_WIDTH * 0.84, height: CARD_THUMB_HEIGHT * 0.84),
                    cornerRadius: 6,
                    showShadow: true,
//                    showBorder: true
                )
                .offset(x: -6, y: -6)
                .rotationEffect(.degrees(-4))
            }

            // Middle page (2nd) if available
            if let secondary {
                ThumbnailView(
                    url: secondary,
                    size: CGSize(width: CARD_THUMB_WIDTH * 0.88, height: CARD_THUMB_HEIGHT * 0.88),
                    cornerRadius: 6,
                    showShadow: true,
//                    showBorder: true
                )
                .offset(x: tertiary != nil ? 6 : 6, y: -4)
                .rotationEffect(.degrees(4.5))
            }

            // Front page (1st)
            ThumbnailView(
                url: primary,
                size: CGSize(width: CARD_THUMB_WIDTH * 0.92, height: CARD_THUMB_HEIGHT * 0.92),
                cornerRadius: 6,
                showShadow: true,
//                showBorder: true
            )
            .offset(x: secondary != nil ? -2 : 0, y: secondary != nil ? 4 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFolderPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .overlay(
                Image(systemName: "folder")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
    }

    private var folderBadge: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.285)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)

            Image(systemName: "folder.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: 55, height: 55)
    }

    private var folderName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    private var displaySubtitle: String {
        if let subtitle {
            return subtitle
        }
        guard let contents else {
            return "Scanning…"
        }
        return contents.summary
    }

    private func loadFolderContents() {
        let items = DirectoryScanner.items(in: url)
        let pdfs = items.filter { !$0.isDirectory }.map(\.url)
        let folders = items.filter(\.isDirectory).map(\.url)

        // Gather up to 3 preview PDFs for the 3-layer stack
        var previewPDFs = Array(pdfs.prefix(3))
        if previewPDFs.count < 3 {
            for folder in folders {
                let subItems = DirectoryScanner.items(in: folder)
                let subPDFs = subItems.filter { !$0.isDirectory }.map(\.url)
                for subPDF in subPDFs {
                    previewPDFs.append(subPDF)
                    if previewPDFs.count >= 3 { break }
                }
                if previewPDFs.count >= 3 { break }
            }
        }

        contents = FolderContents(
            pdfCount: pdfs.count,
            folderCount: folders.count,
            previewPDFs: previewPDFs
        )
    }
}

// MARK: - Folder Contents Model

private struct FolderContents {
    let pdfCount: Int
    let folderCount: Int
    let previewPDFs: [URL]

    var summary: String {
        if pdfCount == 0 && folderCount == 0 {
            return "Empty"
        }
        if folderCount == 0 {
            return pdfCount == 1 ? "1 PDF" : "\(pdfCount) PDFs"
        }
        if pdfCount == 0 {
            return folderCount == 1 ? "1 folder" : "\(folderCount) folders"
        }
        let pdfText = pdfCount == 1 ? "1 PDF" : "\(pdfCount) PDFs"
        let folderText = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
        return "\(pdfText), \(folderText)"
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Folder Stacks - Standard Canvas") {
    LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 130), spacing: 14)],
        alignment: .leading,
        spacing: 14
    ) {
        ForEach(DevelopmentConfiguration.demoFolderURLs, id: \.self) { folderURL in
            FolderStackView(url: folderURL)
        }
    }
    .padding(24)
    .frame(width: 650)
}

#Preview("Folder Stacks - Translucent Glass Canvas") {
    ZStack {
        // Colorful wallpaper background to showcase frosted glass effect
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
            .fill(Color.purple.opacity(0.40))
            .frame(width: 280, height: 280)
            .blur(radius: 50)
            .offset(x: -140, y: -40)

        Circle()
            .fill(Color.orange.opacity(0.30))
            .frame(width: 250, height: 250)
            .blur(radius: 45)
            .offset(x: 130, y: 70)

        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 16)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(DevelopmentConfiguration.demoFolderURLs, id: \.self) { folderURL in
                FolderStackView(url: folderURL)
            }
        }
        .padding(28)
    }
    .frame(width: 680, height: 440)
}
#endif
