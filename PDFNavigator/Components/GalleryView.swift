import AppKit
import SwiftUI

enum GalleryItem: Hashable, Identifiable {
    case folder(URL)
    case pdf(URL)

    var id: Self { self }

    var url: URL {
        switch self {
        case .folder(let url), .pdf(let url): url
        }
    }
}

struct GallerySection: Identifiable {
    enum ID: Hashable {
        case recents
        case folders
        case pdfs
    }

    let id: ID
    let title: String
    let items: [GalleryItem]
    var collapsedRowCount: Int?

    init(
        id: ID,
        title: String,
        items: [GalleryItem],
        collapsedRowCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.collapsedRowCount = collapsedRowCount
    }
}

/// The SwiftUI gallery shared by the Library and Recents surfaces.
///
/// Selection and focus are deliberately local presentation state. Opening an
/// item leaves through the supplied callbacks, so `WorkspaceSession` remains
/// the only owner of navigation in the current tab.
struct GalleryView: View {
    private static let minimumCardWidth: CGFloat = 130
    private static let spacing: CGFloat = 14

    let sections: [GallerySection]
    let emptySymbolName: String
    let emptyMessage: String
    let onOpenPDF: (URL) -> Void
    let onOpenFolder: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void
    let onRevealInFinder: (URL) -> Void

    @State private var selectedItem: GalleryItem?
    @FocusState private var isFocused: Bool
    @State private var expandedSections: Set<GallerySection.ID> = []
    @State private var columnCount = 1

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.minimumCardWidth), spacing: Self.spacing)]
    }

    private var populatedSections: [GallerySection] {
        sections.filter { !$0.items.isEmpty }
    }

    private var visibleItems: [GalleryItem] {
        populatedSections.flatMap(visibleItems(in:))
    }

    var body: some View {
        Group {
            if populatedSections.isEmpty {
                GalleryEmptyState(
                    symbolName: emptySymbolName,
                    message: emptyMessage
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(populatedSections) { section in
                                sectionView(section)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: selectedItem) { _, item in
                        if let item {
                            proxy.scrollTo(item)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onMoveCommand(perform: moveSelection)
        .onKeyPress(.return) {
            guard let selectedItem else { return .ignored }
            open(selectedItem)
            return .handled
        }
        .onExitCommand {
            selectedItem = nil
        }
        .onGeometryChange(for: Int.self) { proxy in
            max(
                1,
                Int((proxy.size.width - 56 + Self.spacing)
                    / (Self.minimumCardWidth + Self.spacing))
            )
        } action: { newColumnCount in
            columnCount = newColumnCount
            discardHiddenSelection()
        }
    }

    private func sectionView(_ section: GallerySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GallerySectionHeader(
                    title: section.title,
                    count: section.items.count
                )

                if canToggleExpansion(of: section) {
                    Button(
                        expandedSections.contains(section.id)
                            ? "Show Less"
                            : "Show All"
                    ) {
                        toggleExpansion(of: section)
                    }
                    .buttonStyle(.link)
                }
            }

            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: Self.spacing
            ) {
                ForEach(visibleItems(in: section)) { item in
                    card(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func card(for item: GalleryItem) -> some View {
        Group {
            switch item {
            case .folder(let url):
                FolderCardView(url: url, isSelected: selectedItem == item)
            case .pdf(let url):
                FileCardView(
                    url: url,
                    subtitle: url.deletingLastPathComponent().lastPathComponent,
                    isSelected: selectedItem == item
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
            isFocused = true
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { open(item) }
        )
        .contextMenu {
            contextMenu(for: item)
        }
        .accessibilityAddTraits(selectedItem == item ? .isSelected : [])
        .accessibilityAction(.default) {
            open(item)
        }
    }

    @ViewBuilder
    private func contextMenu(for item: GalleryItem) -> some View {
        Button("Open") {
            open(item)
        }

        if case .pdf(let url) = item {
            Button("Open in New Tab") {
                onOpenPDFInNewTab(url)
            }
        }

        Divider()

        Button("Open in Default App") {
            NSWorkspace.shared.open(item.url)
        }

        Button("Show in Finder") {
            onRevealInFinder(item.url)
        }
    }

    private func open(_ item: GalleryItem) {
        switch item {
        case .folder(let url): onOpenFolder(url)
        case .pdf(let url): onOpenPDF(url)
        }
    }

    private func visibleItems(in section: GallerySection) -> [GalleryItem] {
        guard
            let rowCount = section.collapsedRowCount,
            !expandedSections.contains(section.id)
        else { return section.items }

        return Array(section.items.prefix(columnCount * rowCount))
    }

    private func canToggleExpansion(of section: GallerySection) -> Bool {
        guard let rowCount = section.collapsedRowCount else { return false }
        return section.items.count > columnCount * rowCount
    }

    private func toggleExpansion(of section: GallerySection) {
        if expandedSections.contains(section.id) {
            expandedSections.remove(section.id)
        } else {
            expandedSections.insert(section.id)
        }
        discardHiddenSelection()
    }

    private func discardHiddenSelection() {
        guard let selectedItem, !visibleItems.contains(selectedItem) else { return }
        self.selectedItem = nil
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !visibleItems.isEmpty else { return }

        guard
            let selectedItem,
            let index = visibleItems.firstIndex(of: selectedItem)
        else {
            self.selectedItem = switch direction {
            case .left, .up: visibleItems.last
            case .right, .down: visibleItems.first
            @unknown default: nil
            }
            return
        }

        let offset = switch direction {
        case .left: -1
        case .right: 1
        case .up: -columnCount
        case .down: columnCount
        @unknown default: 0
        }
        guard offset != 0 else { return }

        let destination = min(max(index + offset, 0), visibleItems.count - 1)
        self.selectedItem = visibleItems[destination]
    }
}

#if DEBUG
#Preview("Shared Gallery") {
    GalleryView(
        sections: [
            GallerySection(
                id: .folders,
                title: "Folders",
                items: DevelopmentConfiguration.demoFolderURLs.map(GalleryItem.folder)
            ),
            GallerySection(
                id: .pdfs,
                title: "PDFs",
                items: DevelopmentConfiguration.loadPDFs(limit: 20).map(GalleryItem.pdf)
            ),
        ],
        emptySymbolName: "doc.text.magnifyingglass",
        emptyMessage: "This workspace has no PDFs yet",
        onOpenPDF: { _ in },
        onOpenFolder: { _ in },
        onOpenPDFInNewTab: { _ in },
        onRevealInFinder: { _ in }
    )
    .frame(width: 800, height: 650)
}
#endif
