import AppKit
import PDFKit
import SwiftUI

struct PDFThumbnailsView: View {
    let document: PDFDocument
    let currentPageIndex: Int?
    let onSelectPage: (Int) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                    if let page = document.page(at: pageIndex) {
                        Button {
                            onSelectPage(pageIndex)
                        } label: {
                            PDFThumbnailCell(
                                page: page,
                                pageNumber: pageIndex + 1,
                                isSelected: currentPageIndex == pageIndex
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Go to page \(pageIndex + 1)")
                    }
                }
            }
            .padding(14)
        }
    }
}

private struct PDFThumbnailCell: View {
    let page: PDFPage
    let pageNumber: Int
    let isSelected: Bool

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 5) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle()
                        .fill(.background)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                }
            }
            .aspectRatio(pageAspectRatio, contentMode: .fit)
            .background(.background)
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 2 : 1
                    )
            }

            Text("Page \(pageNumber)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .task(id: ObjectIdentifier(page)) {
            image = page.thumbnail(
                of: NSSize(width: 600, height: 900),
                for: .cropBox
            )
        }
    }

    private var pageAspectRatio: CGFloat {
        let size = page.bounds(for: .cropBox).size
        guard size.height > 0 else { return 0.72 }
        return size.width / size.height
    }
}

#if DEBUG
#Preview("PDF Thumbnails") {
    let session = PDFSession(url: DevelopmentConfiguration.demoPDFURL)

    if let document = session.document {
        PDFThumbnailsView(
            document: document,
            currentPageIndex: 0,
            onSelectPage: { _ in }
        )
        .frame(width: 300, height: 620)
    } else {
        ContentUnavailableView("PDF Unavailable", systemImage: "doc")
    }
}
#endif
