import CoreGraphics
import Observation

/// The small piece of live `PDFView` state that SwiftUI presentation needs.
///
/// `PDFSession` remains the owner of document and search state. This object is
/// only a read-only projection of the AppKit reader's current presentation.
@Observable
final class PDFReaderPresentationState {
    private(set) var currentPageIndex: Int?
    private(set) var scaleFactor: CGFloat = 1
    private(set) var isZoomToFit = true

    func update(
        currentPageIndex: Int?,
        scaleFactor: CGFloat,
        isZoomToFit: Bool
    ) {
        self.currentPageIndex = currentPageIndex
        self.scaleFactor = scaleFactor
        self.isZoomToFit = isZoomToFit
    }
}
