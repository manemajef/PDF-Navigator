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

        displayPDF(
            at: url,
            in: pdfView,
            coordinator: context.coordinator
        )
        controller.attach(pdfView, url: url)
        controller.search(for: searchText)

        return pdfView
    }

    func updateNSView(
        _ pdfView: NavigatorPDFView,
        context: Context
    ) {
        if context.coordinator.currentURL != url {
            displayPDF(
                at: url,
                in: pdfView,
                coordinator: context.coordinator
            )
        }

        controller.attach(
            pdfView,
            url: context.coordinator.currentURL ?? url
        )
        controller.search(for: searchText)
    }

    static func dismantleNSView(
        _ pdfView: NavigatorPDFView,
        coordinator: Coordinator
    ) {
        coordinator.controller.detach(pdfView)
    }

    private func displayPDF(
        at url: URL,
        in pdfView: NavigatorPDFView,
        coordinator: Coordinator
    ) {
        controller.willDisplayDocument(at: url)

        guard let document = controller.document(
            for: url
        ) else {
            return
        }

        pdfView.display(
            document: document,
            position: controller.position(for: url)
        )
        coordinator.currentURL = url
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
    private var pendingPosition: ReadingPosition?

    func display(
        document: PDFDocument,
        position: ReadingPosition?
    ) {
        self.document = document
        pendingPosition = position
        needsInitialFit = position == nil
        needsLayout = true
    }

    override func layout() {
        super.layout()

        guard
            document != nil,
            bounds.width > 0,
            bounds.height > 0
        else {
            return
        }

        if let pendingPosition {
            restore(pendingPosition)
            self.pendingPosition = nil
        } else if needsInitialFit {
            needsInitialFit = false
            autoScales = false
            scaleFactor = scaleFactorForSizeToFit
        }
    }

    private func restore(_ position: ReadingPosition) {
        guard
            let document,
            let page = document.page(
                at: position.pageIndex
            )
        else {
            needsInitialFit = true
            return
        }

        autoScales = false
        let destination = PDFDestination(
            page: page,
            at: CGPoint(
                x: position.pointX,
                y: position.pointY
            )
        )
        destination.zoom = position.scaleFactor
        go(to: destination)
    }
}
