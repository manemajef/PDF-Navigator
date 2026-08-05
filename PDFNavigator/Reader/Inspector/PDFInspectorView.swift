import PDFKit
import SwiftUI

/// SwiftUI content hosted by the native AppKit inspector split item.
struct PDFInspectorView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case thumbnails
        case outline
        case info

        var id: Self { self }

        var title: String {
            switch self {
            case .thumbnails: "Thumbnails"
            case .outline: "Contents"
            case .info: "Info"
            }
        }

        var symbol: String {
            switch self {
            case .thumbnails: "square.grid.2x2"
            case .outline: "list.bullet.indent"
            case .info: "info.circle"
            }
        }
    }

    let session: PDFSession
    let readerState: PDFReaderPresentationState
    let onSelectPage: (Int) -> Void
    let onSelectOutline: (PDFOutline) -> Void

    @State private var section = Section.thumbnails

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $section) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .labelStyle(.iconOnly)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(section.title)
            .padding(10)

            Divider()

            if let document = session.document {
                switch section {
                case .thumbnails:
                    PDFThumbnailsView(
                        document: document,
                        currentPageIndex: readerState.currentPageIndex,
                        onSelectPage: onSelectPage
                    )

                case .outline:
                    PDFOutlineView(
                        document: document,
                        onSelectOutline: onSelectOutline
                    )

                case .info:
                    PDFInfoView(
                        session: session,
                        readerState: readerState
                    )
                }
            } else {
                ContentUnavailableView(
                    "PDF Unavailable",
                    systemImage: "doc.badge.ellipsis"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("PDF Inspector") {
    let readerState = PDFReaderPresentationState()
    readerState.update(
        currentPageIndex: 0,
        scaleFactor: 1,
        isZoomToFit: true
    )

    return PDFInspectorView(
        session: PDFSession(url: DevelopmentConfiguration.demoPDFURL),
        readerState: readerState,
        onSelectPage: { _ in },
        onSelectOutline: { _ in }
    )
    .frame(width: 240, height: 620)
}
#endif
