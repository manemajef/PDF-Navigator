import SwiftUI

struct NavigatorView: NSViewControllerRepresentable {
    let rootURL: URL
    let selectedPDFURL: URL?
    let onSelectPDF: (URL) -> Void
    let onOpenInNewTab: (URL, TabActivation) -> Void
    @Binding var itemCount: Int?

    func makeNSViewController(context: Context) -> NavigatorController {
        NavigatorController(
            rootURL: rootURL,
            selectedPDFURL: selectedPDFURL,
            onSelectPDF: onSelectPDF,
            onOpenInNewTab: onOpenInNewTab,
            onItemCountChange: { itemCount = $0 }
        )
    }

    func updateNSViewController(
        _ controller: NavigatorController,
        context: Context
    ) {
        controller.update(
            rootURL: rootURL,
            selectedPDFURL: selectedPDFURL,
            onSelectPDF: onSelectPDF,
            onOpenInNewTab: onOpenInNewTab,
            onItemCountChange: { itemCount = $0 }
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsViewController: NavigatorController,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}
