import AppKit
import SwiftUI

private let CARD_THUMB_WIDTH: CGFloat = 120.0

/// A frosted glass square card representing a folder with a grid of mini document previews inside (iOS folder style).
struct FolderCardView: View {
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
                glassGridThumbnail

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
                .frame(maxWidth: CARD_THUMB_WIDTH, maxHeight: CARD_THUMB_WIDTH, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .task(id: url) {
            loadFolderContents()
        }
    }

    // MARK: - Glass Grid Thumbnail

    private var glassGridThumbnail: some View {
        let glassCornerRadius: CGFloat = 20
        let miniPageWidth: CGFloat = 43
        let miniPageHeight: CGFloat = 43 * 1.32
        let previewPDFs = contents?.previewPDFs ?? []

        return ZStack {
            // Frosted Glass Container
            RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

            // Content inside glass square
            if previewPDFs.isEmpty {
                Image(systemName: "folder.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary.opacity(0.7))
            } else if previewPDFs.count == 1 {
                ThumbnailView(
                    url: previewPDFs[0],
                    size: CGSize(width: 68, height: 68 * 1.35),
                    cornerRadius: 5,
                    showShadow: true,
//                    showBorder: true
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(miniPageWidth), spacing: 8),
                        GridItem(.fixed(miniPageWidth), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(Array(previewPDFs.prefix(4).enumerated()), id: \.offset) { _, pdfURL in
                        ThumbnailView(
                            url: pdfURL,
                            size: CGSize(width: miniPageWidth, height: miniPageHeight),
                            cornerRadius: 3.5,
                            showShadow: true,
//                            showBorder: true
                        )
                    }
                }
            }
        }
        .frame(width: CARD_THUMB_WIDTH, height: CARD_THUMB_WIDTH * 1.15)
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

        // Gather up to 4 preview PDFs for mini grid
        var previewPDFs = Array(pdfs.prefix(4))
        if previewPDFs.count < 4 {
            for folder in folders {
                let subItems = DirectoryScanner.items(in: folder)
                let subPDFs = subItems.filter { !$0.isDirectory }.map(\.url)
                for subPDF in subPDFs {
                    previewPDFs.append(subPDF)
                    if previewPDFs.count >= 4 { break }
                }
                if previewPDFs.count >= 4 { break }
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

// MARK: - Previews with Vibrant Glass Backdrops

#if DEBUG
#Preview("Folder Cards - Standard Canvas") {
    LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 130), spacing: 14)],
        alignment: .leading,
        spacing: 14
    ) {
        ForEach(DevelopmentConfiguration.demoFolderURLs, id: \.self) { folderURL in
            FolderCardView(url: folderURL)
        }
    }
    .padding(24)
    .frame(width: 650)
}

#Preview("Folder Cards - Translucent Glass Canvas") {
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
            .fill(Color.cyan.opacity(0.35))
            .frame(width: 260, height: 260)
            .blur(radius: 50)
            .offset(x: -120, y: -60)

        Circle()
            .fill(Color.pink.opacity(0.30))
            .frame(width: 240, height: 240)
            .blur(radius: 45)
            .offset(x: 140, y: 60)

        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 16)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(DevelopmentConfiguration.demoFolderURLs, id: \.self) { folderURL in
                FolderCardView(url: folderURL)
            }
        }
        .padding(28)
    }
    .frame(width: 680, height: 420)
}
#endif
