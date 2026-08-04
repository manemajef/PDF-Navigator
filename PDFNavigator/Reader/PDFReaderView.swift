import SwiftUI
import PDFKit

struct PDFReaderView: NSViewControllerRepresentable {
    let controller: PDFReaderController
    let pdfSession: PDFSession?

    init(controller: PDFReaderController, pdfSession: PDFSession?) {
        self.controller = controller
        self.pdfSession = pdfSession
    }

    func makeNSViewController(context: Context) -> PDFReaderController {
        if let pdfSession {
            controller.display(pdfSession)
        }
        return controller
    }

    func updateNSViewController(_ nsViewController: PDFReaderController, context: Context) {
        if let pdfSession {
            nsViewController.display(pdfSession)
        }
    }
}

#if DEBUG
    #Preview("PDF Reader View") {
        let controller = PDFReaderController()
        let session = PDFSession(url: DevelopmentConfiguration.demoPDFURL)
        return PDFReaderView(controller: controller, pdfSession: session)
            .frame(width: 600, height: 750)
    }
#endif
