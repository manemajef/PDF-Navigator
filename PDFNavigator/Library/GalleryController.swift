import AppKit
import SwiftUI

/// Presents one folder's contents as a selectable grid.
///
/// Owns no file data. It is handed the folders and PDFs to show, projects them
/// into an `NSCollectionView`, and turns activation into the callbacks it was
/// given. Selection, multi-select, arrow keys, and rubber-band all come from
/// the collection view; nothing here re-implements them.
final class GalleryController: NSViewController {
    /// One section per kind. Empty kinds are omitted entirely, so an empty
    /// section can never draw a header with nothing under it.
    private enum Section {
        case folders
        case pdfs
    }

    private static let minimumItemWidth: CGFloat = 130
    private static let spacing: CGFloat = 14
    private static let sectionSpacing: CGFloat = 28
    private static let contentInset: CGFloat = 28
    private static let headerHeight: CGFloat = 20
    /// Cards are fixed height per kind: a PDF card is a full thumbnail plus a
    /// label, a folder card is a 100pt tile plus a label. Tune here.
    private static let folderItemHeight: CGFloat = 168
    private static let pdfItemHeight: CGFloat = 250

    private let scrollView = NSScrollView()
    private let collectionView = GalleryCollectionView()
    private lazy var emptyStateView = NSHostingView(
        rootView: GalleryEmptyState(message: emptyMessage)
    )

    private let onOpenPDF: (URL) -> Void
    private let onOpenFolder: (URL) -> Void

    private var folderURLs: [URL] = []
    private var pdfURLs: [URL] = []
    private var emptyMessage = ""

    /// The sections that currently have content, in display order.
    private var sections: [Section] {
        var sections: [Section] = []
        if !folderURLs.isEmpty { sections.append(.folders) }
        if !pdfURLs.isEmpty { sections.append(.pdfs) }
        return sections
    }

    init(
        onOpenPDF: @escaping (URL) -> Void,
        onOpenFolder: @escaping (URL) -> Void
    ) {
        self.onOpenPDF = onOpenPDF
        self.onOpenFolder = onOpenFolder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func loadView() {
        collectionView.collectionViewLayout = makeLayout()
        collectionView.dataSource = self
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = true
        // One line to turn on shift/command range selection when you want it.
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]

        collectionView.register(
            GalleryCollectionItem.self,
            forItemWithIdentifier: GalleryCollectionItem.identifier
        )
        collectionView.register(
            GallerySectionHeaderView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: GallerySectionHeaderView.identifier
        )

        // Return activates whatever is selected, matching a source list.
        collectionView.onActivateSelection = { [weak self] in
            self?.openSelection()
        }

        // A second click opens. `delaysPrimaryMouseButtonEvents = false` is what
        // keeps the *first* click immediate: left on, AppKit would hold every
        // press back until it knew a double click was not coming.
        let doubleClick = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleDoubleClick(_:))
        )
        doubleClick.numberOfClicksRequired = 2
        doubleClick.delaysPrimaryMouseButtonEvents = false
        collectionView.addGestureRecognizer(doubleClick)

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        let container = NSView()
        container.addSubview(scrollView)
        container.addSubview(emptyStateView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            emptyStateView.topAnchor.constraint(equalTo: container.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }

    /// Shows `folderURLs` and `pdfURLs`. Safe to call as often as convenient.
    func render(folderURLs: [URL], pdfURLs: [URL], emptyMessage: String) {
        self.folderURLs = folderURLs
        self.pdfURLs = pdfURLs
        self.emptyMessage = emptyMessage

        loadViewIfNeeded()
        emptyStateView.rootView = GalleryEmptyState(message: emptyMessage)

        let isEmpty = folderURLs.isEmpty && pdfURLs.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty

        collectionView.reloadData()
    }

    // MARK: - Activation

    @objc private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        let point = recognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        open(at: indexPath)
    }

    private func openSelection() {
        guard let indexPath = collectionView.selectionIndexPaths.first else { return }
        open(at: indexPath)
    }

    private func open(at indexPath: IndexPath) {
        guard let url = url(at: indexPath) else { return }
        switch sections[indexPath.section] {
        case .folders: onOpenFolder(url)
        case .pdfs: onOpenPDF(url)
        }
    }

    private func url(at indexPath: IndexPath) -> URL? {
        guard indexPath.section < sections.count else { return nil }
        let urls = switch sections[indexPath.section] {
        case .folders: folderURLs
        case .pdfs: pdfURLs
        }
        guard indexPath.item < urls.count else { return nil }
        return urls[indexPath.item]
    }

    // MARK: - Layout

    /// Columns are computed from the available width, reproducing SwiftUI's
    /// `GridItem(.adaptive(minimum:))` behaviour.
    private func makeLayout() -> NSCollectionViewCompositionalLayout {
        let configuration = NSCollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = Self.sectionSpacing

        return NSCollectionViewCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, environment in
                guard let self, sectionIndex < sections.count else { return nil }
                return makeSection(
                    for: sections[sectionIndex],
                    in: environment
                )
            },
            configuration: configuration
        )
    }

    private func makeSection(
        for section: Section,
        in environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let availableWidth = environment.container.effectiveContentSize.width
            - (Self.contentInset * 2)
        let columns = max(
            1,
            Int((availableWidth + Self.spacing) / (Self.minimumItemWidth + Self.spacing))
        )

        let itemHeight = switch section {
        case .folders: Self.folderItemHeight
        case .pdfs: Self.pdfItemHeight
        }

        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(1)
            )
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(itemHeight)
            ),
            subitem: item,
            count: columns
        )
        group.interItemSpacing = NSCollectionLayoutSpacing.fixed(Self.spacing)

        let layoutSection = NSCollectionLayoutSection(group: group)
        layoutSection.interGroupSpacing = Self.spacing
        layoutSection.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: Self.contentInset,
            bottom: 0,
            trailing: Self.contentInset
        )

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(Self.headerHeight)
            ),
            elementKind: NSCollectionView.elementKindSectionHeader,
            alignment: .top
        )
        layoutSection.boundarySupplementaryItems = [header]

        return layoutSection
    }
}

// MARK: - Data source

extension GalleryController: NSCollectionViewDataSource {
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        sections.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        switch sections[section] {
        case .folders: folderURLs.count
        case .pdfs: pdfURLs.count
        }
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: GalleryCollectionItem.identifier,
            for: indexPath
        )

        guard let galleryItem = item as? GalleryCollectionItem,
              let url = url(at: indexPath) else {
            return item
        }

        switch sections[indexPath.section] {
        case .folders:
            galleryItem.configure { isSelected in
                AnyView(FolderCardView(url: url, isSelected: isSelected))
            }
        case .pdfs:
            let subtitle = url.deletingLastPathComponent().lastPathComponent
            galleryItem.configure { isSelected in
                AnyView(
                    FileCardView(
                        url: url,
                        subtitle: subtitle,
                        isSelected: isSelected
                    )
                )
            }
        }

        return galleryItem
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
        at indexPath: IndexPath
    ) -> NSView {
        let view = collectionView.makeSupplementaryView(
            ofKind: kind,
            withIdentifier: GallerySectionHeaderView.identifier,
            for: indexPath
        )

        guard let header = view as? GallerySectionHeaderView,
              indexPath.section < sections.count else {
            return view
        }

        switch sections[indexPath.section] {
        case .folders:
            header.configure(title: "Folders", count: folderURLs.count)
        case .pdfs:
            header.configure(title: "PDFs", count: pdfURLs.count)
        }

        return header
    }
}

/// A collection view that activates its selection on Return.
///
/// Handled here rather than in the controller because `keyDown` is a responder
/// concern: arrow keys, type-select, and the rest already belong to the view,
/// and Return is the one it does not answer on its own.
private final class GalleryCollectionView: NSCollectionView {
    var onActivateSelection: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.charactersIgnoringModifiers.map {
            $0 == "\r" || $0 == "\n"
        } ?? false

        guard isReturn, !selectionIndexPaths.isEmpty else {
            super.keyDown(with: event)
            return
        }
        onActivateSelection?()
    }
}
