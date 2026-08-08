import CoreGraphics
import Observation

/// The small piece of live `PDFView` state that SwiftUI presentation needs.
///
/// `PDFSession` remains the owner of document and search state. This object is
/// only a read-only projection of the AppKit reader's current presentation.
@Observable
final class PDFReaderPresentationState {
    private(set) var currentPageIndex: Int?
    private(set) var pageCount = 0
    private(set) var scaleFactor: CGFloat = 1
    private(set) var isZoomToFit = true

    /// The titlebar subtitle, in the shape Preview uses. `pageCount` is known
    /// the moment a document is set, so this is never nil while one is open —
    /// the subtitle does not blank out mid-swap waiting for a current page.
    var pageSummary: String? {
        guard pageCount > 0 else { return nil }
        return "Page \((currentPageIndex ?? 0) + 1) of \(pageCount)"
    }

    func update(
        currentPageIndex: Int?,
        pageCount: Int,
        scaleFactor: CGFloat,
        isZoomToFit: Bool
    ) {
        // Scrolling recomputes this on every clip-view bounds change, and
        // assigning an unchanged value still notifies observers. Diff first so
        // a scroll within one page doesn't rebuild the inspector.
        if self.currentPageIndex != currentPageIndex {
            self.currentPageIndex = currentPageIndex
        }
        if self.pageCount != pageCount {
            self.pageCount = pageCount
        }
        if self.scaleFactor != scaleFactor {
            self.scaleFactor = scaleFactor
        }
        if self.isZoomToFit != isZoomToFit {
            self.isZoomToFit = isZoomToFit
        }
    }
}
