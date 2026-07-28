import PDFKit
import SwiftUI

struct PDFReaderView: NSViewRepresentable {
    let url: URL
    let searchText: String
    let handle: PDFReaderHandle

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ReadingPDFView {
        let view = ReadingPDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.displayBox = .cropBox
        view.backgroundColor = .underPageBackgroundColor

        display(url, in: view, coordinator: context.coordinator)
        handle.attach(view)
        context.coordinator.search.update(searchText, in: view)
        return view
    }

    func updateNSView(_ view: ReadingPDFView, context: Context) {
        if context.coordinator.currentURL != url {
            display(url, in: view, coordinator: context.coordinator)
        }
        handle.attach(view)
        context.coordinator.search.update(searchText, in: view)
    }

    static func dismantleNSView(
        _ view: ReadingPDFView,
        coordinator: Coordinator
    ) {
        coordinator.savePosition(in: view)
        coordinator.search.clear()
        coordinator.handle?.detach(view)
    }

    private func display(
        _ url: URL,
        in view: ReadingPDFView,
        coordinator: Coordinator
    ) {
        coordinator.savePosition(in: view)
        coordinator.search.clear()
        coordinator.handle = handle

        guard let document = PDFDocument(url: url) else {
            view.display(document: nil, position: nil)
            coordinator.currentURL = url
            return
        }

        for pageIndex in 0..<document.pageCount {
            document.page(at: pageIndex)?.annotations.forEach {
                $0.isReadOnly = true
            }
        }

        view.display(
            document: document,
            position: coordinator.positions.position(for: url)
        )
        coordinator.currentURL = url
    }

    final class Coordinator {
        let search = PDFSearch()
        let positions = ReadingPositionStore()
        weak var handle: PDFReaderHandle?
        var currentURL: URL?

        func savePosition(in view: PDFView) {
            guard let url = currentURL,
                  let document = view.document,
                  let destination = view.currentDestination,
                  let page = destination.page else {
                return
            }

            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return }

            positions.save(
                ReadingPosition(
                    pageIndex: pageIndex,
                    pointX: destination.point.x,
                    pointY: destination.point.y,
                    zoom: view.scaleFactor
                ),
                for: url
            )
        }
    }
}

@MainActor
final class PDFReaderHandle {
    private(set) weak var view: PDFView?

    var hasDocument: Bool { view?.document != nil }

    func attach(_ view: PDFView) {
        self.view = view
    }

    func detach(_ view: PDFView) {
        if self.view === view {
            self.view = nil
        }
    }
}

final class ReadingPDFView: PDFView {
    private var pendingPosition: ReadingPosition?
    private var needsInitialFit = false

    func display(document: PDFDocument?, position: ReadingPosition?) {
        self.document = document
        pendingPosition = position
        needsInitialFit = document != nil && position == nil
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard document != nil, bounds.width > 0, bounds.height > 0 else { return }

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
        guard let document, let page = document.page(at: position.pageIndex) else {
            needsInitialFit = true
            return
        }

        autoScales = false
        let destination = PDFDestination(
            page: page,
            at: CGPoint(x: position.pointX, y: position.pointY)
        )
        destination.zoom = position.zoom
        go(to: destination)
    }
}
