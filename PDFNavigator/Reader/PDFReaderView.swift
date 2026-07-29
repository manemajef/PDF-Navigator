import CoreGraphics
import PDFKit
import SwiftUI

struct PDFReaderView: NSViewRepresentable {
    let url: URL
    let searchText: String
    let handle: PDFReaderHandle

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.displayBox = .cropBox
//        view.backgroundColor = .underPageBackgroundColor

        display(url, in: view, coordinator: context.coordinator)
        context.coordinator.observeMagnification(in: view)
        handle.attach(view, search: context.coordinator.search)
        context.coordinator.search.update(searchText, in: view)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if context.coordinator.currentURL != url {
            display(url, in: view, coordinator: context.coordinator)
        }
        handle.attach(view, search: context.coordinator.search)
        context.coordinator.search.update(searchText, in: view)
    }

    static func dismantleNSView(
        _ view: PDFView,
        coordinator: Coordinator
    ) {
        coordinator.savePosition(in: view)
        coordinator.search.clear()
        coordinator.stopObservingMagnification()
    }

    private func display(
        _ url: URL,
        in view: PDFView,
        coordinator: Coordinator
    ) {
        coordinator.savePosition(in: view)
        coordinator.search.clear()

        guard let document = PDFDocument(url: url) else {
            view.document = nil
            coordinator.currentURL = url
            return
        }

        for pageIndex in 0..<document.pageCount {
            document.page(at: pageIndex)?.annotations.forEach {
                $0.isReadOnly = true
            }
        }

        view.autoScales = true
        view.document = document

        if let position = coordinator.positions.position(for: url),
           let page = document.page(at: position.pageIndex) {
            let destination = PDFDestination(
                page: page,
                at: CGPoint(x: position.pointX, y: position.pointY)
            )
            destination.zoom = position.zoom
            view.go(to: destination)
            view.autoScales = true
        }

        coordinator.currentURL = url
    }

    final class Coordinator {
        let search = PDFSearch()
        let positions = ReadingPositionStore()
        var currentURL: URL?
        private var magnificationObserver: NSObjectProtocol?

        func observeMagnification(in view: PDFView) {
            guard magnificationObserver == nil else { return }
            magnificationObserver = NotificationCenter.default.addObserver(
                forName: NSScrollView.willStartLiveMagnifyNotification,
                object: nil,
                queue: .main
            ) { [weak view] notification in
                guard let view,
                      let scrollView = notification.object as? NSScrollView,
                      scrollView === view.documentView?.enclosingScrollView else {
                    return
                }
                view.autoScales = false
            }
        }

        func stopObservingMagnification() {
            if let magnificationObserver {
                NotificationCenter.default.removeObserver(magnificationObserver)
                self.magnificationObserver = nil
            }
        }

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

extension PDFView {
    func showPrintSize() {
        autoScales = false
        scaleFactor = printSizeScaleFactor
    }

    private var printSizeScaleFactor: CGFloat {
        guard let screen = window?.screen ?? NSScreen.main,
              let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? CGDirectDisplayID else {
            return 1
        }

        let physicalWidth = CGDisplayScreenSize(displayID).width
        guard physicalWidth > 0 else { return 1 }

        return screen.frame.width / (physicalWidth / 25.4) / 72
    }

    func zoomToCurrentSelection() {
        guard let selection = currentSelection,
              let page = selection.pages.first else {
            return
        }

        let selectionBounds = convert(selection.bounds(for: page), from: page)
        guard selectionBounds.width > 0, selectionBounds.height > 0 else { return }

        autoScales = false
        scaleFactor *= min(
            bounds.width / selectionBounds.width,
            bounds.height / selectionBounds.height
        )
        go(to: selection)
    }
}

@MainActor
final class PDFReaderHandle {
    private(set) weak var view: PDFView?
    private weak var search: PDFSearch?

    func attach(_ view: PDFView, search: PDFSearch) {
        self.view = view
        self.search = search
    }

    func selectSearchMatch(backward: Bool) {
        search?.selectMatch(backward: backward)
    }
}
