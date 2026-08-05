#if DEBUG
    import SwiftUI

    /// Preview-only adapter for the production AppKit reader controller.
    private struct PDFReaderPreview: NSViewControllerRepresentable {
        let controller: PDFReaderController
        let session: PDFSession

        func makeNSViewController(context: Context) -> PDFReaderController {
            controller.display(session)
            return controller
        }

        func updateNSViewController(
            _ controller: PDFReaderController,
            context: Context
        ) {
            controller.display(session)
        }
    }

    #Preview("PDF Reader") {
        PDFReaderPreview(
            controller: PDFReaderController(),
            session: PDFSession(url: DevelopmentConfiguration.demoPDFURL)
        )
        .frame(width: 600, height: 750)
    }
#endif
