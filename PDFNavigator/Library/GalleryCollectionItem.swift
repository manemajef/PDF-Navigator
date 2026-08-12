import AppKit
import SwiftUI

/// One gallery cell: an AppKit item whose entire appearance is a SwiftUI view.
///
/// The collection view owns selection; this item only reports it downward. The
/// content closure is called with the current `isSelected`, so the SwiftUI side
/// stays a pure function of (data, selected) and never learns it was clicked.
final class GalleryCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("GalleryCollectionItem")

    private var makeContent: ((Bool) -> AnyView)?
    private var hostingView: PassthroughHostingView<AnyView>?

    override var isSelected: Bool {
        didSet {
            guard isSelected != oldValue else { return }
            renderContent()
        }
    }

    override func loadView() {
        view = NSView()
    }

    /// Installs the SwiftUI content this cell draws.
    ///
    /// Takes a closure rather than a view so the item can rebuild it whenever
    /// selection changes, without the data source being involved.
    func configure(_ makeContent: @escaping (Bool) -> AnyView) {
        self.makeContent = makeContent
        renderContent()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        makeContent = nil
    }

    private func renderContent() {
        guard let makeContent else { return }
        let root = makeContent(isSelected)

        if let hostingView {
            hostingView.rootView = root
            return
        }

        let hosting = PassthroughHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingView = hosting
    }
}

/// A hosting view that draws but is invisible to the mouse.
///
/// Without this the hosting view hit-tests first, swallows the press, and the
/// collection view never learns the item was clicked — selection silently stops
/// working. One event owner: here that is the collection view, so everything
/// above it has to stay out of the way.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// A section title, drawn by SwiftUI and positioned by the compositional layout.
final class GallerySectionHeaderView: NSView, NSCollectionViewElement {
    static let identifier = NSUserInterfaceItemIdentifier("GallerySectionHeaderView")

    private var hostingView: NSHostingView<GallerySectionHeader>?

    func configure(title: String, count: Int) {
        let header = GallerySectionHeader(title: title, count: count)

        if let hostingView {
            hostingView.rootView = header
            return
        }

        let hosting = NSHostingView(rootView: header)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingView = hosting
    }
}
