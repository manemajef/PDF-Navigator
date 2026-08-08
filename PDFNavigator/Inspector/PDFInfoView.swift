import PDFKit
import SwiftUI

struct PDFInfoView: View {
    let session: PDFSession
    let readerState: PDFReaderPresentationState

    var body: some View {
        Form {
            Section("Document") {
                LabeledContent("File", value: session.url.lastPathComponent)
                LabeledContent("Pages", value: pageCount)

                if let title = stringAttribute(.titleAttribute) {
                    LabeledContent("Title", value: title)
                }
                if let author = stringAttribute(.authorAttribute) {
                    LabeledContent("Author", value: author)
                }
                if let subject = stringAttribute(.subjectAttribute) {
                    LabeledContent("Subject", value: subject)
                }
            }

            Section("Reader") {
                LabeledContent("Current Page", value: currentPage)
                LabeledContent("Zoom", value: zoom)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var pageCount: String {
        String(session.document?.pageCount ?? 0)
    }

    private var currentPage: String {
        guard let currentPageIndex = readerState.currentPageIndex else {
            return "—"
        }
        return String(currentPageIndex + 1)
    }

    private var zoom: String {
        if readerState.isZoomToFit {
            return "Fit"
        }
        return Double(readerState.scaleFactor)
            .formatted(.percent.precision(.fractionLength(0)))
    }

    private func stringAttribute(_ key: PDFDocumentAttribute) -> String? {
        let value = session.document?.documentAttributes?[key] as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

#if DEBUG
#Preview("PDF Info") {
    let readerState = PDFReaderPresentationState()
    readerState.update(
        currentPageIndex: 0,
        pageCount: 1,
        scaleFactor: 1,
        isZoomToFit: true
    )

    return PDFInfoView(
        session: PDFSession(url: DevelopmentConfiguration.demoPDFURL),
        readerState: readerState
    )
    .frame(width: 300, height: 620)
}
#endif
