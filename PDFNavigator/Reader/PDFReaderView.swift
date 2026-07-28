import PDFKit
import SwiftUI

struct PDFReaderView: NSViewRepresentable {
    let url: URL
    let searchText: String
    let controller: PDFReaderController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(
        context: Context
    ) -> NavigatorPDFView {
        let pdfView = NavigatorPDFView()

        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.displayBox = .cropBox
        pdfView.backgroundColor = .underPageBackgroundColor

        loadPDF(
            from: url,
            into: pdfView,
            coordinator: context.coordinator
        )
        controller.attach(pdfView)
        controller.search(for: searchText)

        return pdfView
    }

    func updateNSView(
        _ pdfView: NavigatorPDFView,
        context: Context
    ) {
        if context.coordinator.currentURL != url {
            loadPDF(
                from: url,
                into: pdfView,
                coordinator: context.coordinator
            )
        }

        controller.attach(pdfView)
        controller.search(for: searchText)
    }

    static func dismantleNSView(
        _ pdfView: NavigatorPDFView,
        coordinator: Coordinator
    ) {
        coordinator.controller.detach(pdfView)
    }

    private func loadPDF(
        from url: URL,
        into pdfView: NavigatorPDFView,
        coordinator: Coordinator
    ) {
        guard let document = PDFDocument(url: url) else {
            pdfView.display(document: nil)
            coordinator.currentURL = url
            return
        }

        makeFormFieldsReadOnly(in: document)

        pdfView.display(document: document)

        coordinator.currentURL = url
    }

    private func makeFormFieldsReadOnly(
        in document: PDFDocument
    ) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                continue
            }

            for annotation in page.annotations {
                annotation.isReadOnly = true
            }
        }
    }

    final class Coordinator {
        let controller: PDFReaderController
        var currentURL: URL?

        init(controller: PDFReaderController) {
            self.controller = controller
        }
    }
}

final class NavigatorPDFView: PDFView {
    private var needsInitialFit = false

    func display(document: PDFDocument?) {
        self.document = document
        needsInitialFit = document != nil
        needsLayout = true
    }

    override func layout() {
        super.layout()

        guard
            needsInitialFit,
            document != nil,
            bounds.width > 0,
            bounds.height > 0
        else {
            return
        }

        needsInitialFit = false
        autoScales = false
        scaleFactor = scaleFactorForSizeToFit
    }
}
