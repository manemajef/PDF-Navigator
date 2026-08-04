import AppKit
import Combine
import SwiftUI

@Observable
final class SidebarNode: Identifiable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    let level: Int

    var isExpanded: Bool
    var isLoading = false
    var children: [SidebarNode]?

    init(
        url: URL,
        isDirectory: Bool,
        level: Int = 0,
        isExpanded: Bool = false,
        children: [SidebarNode]? = nil
    ) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.level = level
        self.isExpanded = isExpanded
        self.children = children
    }
}

@MainActor
@Observable
final class SidebarViewModel {
    var rootURL: URL?
    var selectedURL: URL?
    var rootNodes: [SidebarNode]
    var isScanning = false

    private var sessionSubscription: AnyCancellable?

    init(
        rootURL: URL? = nil,
        selectedURL: URL? = nil,
        rootNodes: [SidebarNode] = []
    ) {
        self.rootURL = rootURL
        self.selectedURL = selectedURL
        self.rootNodes = rootNodes
    }

    func bind(to session: TabSession) {
        rootURL = session.root
        selectedURL = session.selection
        loadRoot(session.root)

        sessionSubscription = session.changes.sink { [weak self, weak session] change in
            guard let self, let session else { return }
            Task { @MainActor in
                self.selectedURL = session.selection
                if change == .root {
                    self.rootURL = session.root
                    self.loadRoot(session.root)
                }
            }
        }
    }

    func loadRoot(_ root: URL) {
        let root = root.standardizedFileURL
        isScanning = true

        Task {
            let items = (try? await DirectoryScanner.items(in: root)) ?? []
            guard rootURL?.standardizedFileURL == root else { return }

            rootNodes = items.map {
                SidebarNode(url: $0.url, isDirectory: $0.isDirectory)
            }
            isScanning = false
        }
    }

    func toggleExpansion(of node: SidebarNode) {
        guard node.isDirectory else { return }

        node.isExpanded.toggle()
        guard node.isExpanded, node.children == nil else { return }

        node.isLoading = true
        Task {
            let items = (try? await DirectoryScanner.items(in: node.url)) ?? []
            node.children = items.map {
                SidebarNode(
                    url: $0.url,
                    isDirectory: $0.isDirectory,
                    level: node.level + 1
                )
            }
            node.isLoading = false
        }
    }
}

struct SidebarView: View {
    let viewModel: SidebarViewModel
    let onSelectPDF: (URL) -> Void
    let onOpenInNewTab: (URL) -> Void
    let onOpenInDefaultApp: (URL) -> Void
    let onShowInFinder: (URL) -> Void
    let onSearch: () -> Void

    init(
        viewModel: SidebarViewModel,
        onSelectPDF: @escaping (URL) -> Void = { _ in },
        onOpenInNewTab: @escaping (URL) -> Void = { _ in },
        onOpenInDefaultApp: @escaping (URL) -> Void = { _ in },
        onShowInFinder: @escaping (URL) -> Void = { _ in },
        onSearch: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onSelectPDF = onSelectPDF
        self.onOpenInNewTab = onOpenInNewTab
        self.onOpenInDefaultApp = onOpenInDefaultApp
        self.onShowInFinder = onShowInFinder
        self.onSearch = onSearch
    }

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeaderView(
                title: viewModel.rootURL?.lastPathComponent ?? "Workspace",
                onSearch: onSearch
            )

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 24)
                    } else if viewModel.rootNodes.isEmpty {
                        Text("No PDFs in this workspace.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 24)
                    } else {
                        ForEach(visibleNodes) { node in
                            row(for: node)
                        }
                    }
                }
                .padding(6)
            }

            Divider()

            SidebarFooterView(
                itemCount: viewModel.rootNodes.count,
                onOpenInFinder: {
                    if let root = viewModel.rootURL {
                        onShowInFinder(root)
                    }
                }
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(minWidth: 180, maxWidth: 360, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(for node: SidebarNode) -> some View {
        SidebarItemRowView(
            title: node.name,
            isDirectory: node.isDirectory,
            isExpanded: node.isExpanded,
            isSelected: viewModel.selectedURL == node.url,
            level: node.level,
            onToggleExpand: { viewModel.toggleExpansion(of: node) },
            onSelect: { select(node) }
        )
        .contextMenu {
            if !node.isDirectory {
                Button("Open") { open(node.url) }
                Button("Open in New Tab") { onOpenInNewTab(node.url) }
                Divider()
                Button("Open in Default App") { onOpenInDefaultApp(node.url) }
                Button("Show in Finder") { onShowInFinder(node.url) }
            }
        }
    }

    private var visibleNodes: [SidebarNode] {
        flatten(viewModel.rootNodes)
    }

    private func flatten(_ nodes: [SidebarNode]) -> [SidebarNode] {
        nodes.flatMap { node in
            if node.isDirectory, node.isExpanded, let children = node.children {
                return [node] + flatten(children)
            }
            return [node]
        }
    }

    private func select(_ node: SidebarNode) {
        if node.isDirectory {
            viewModel.toggleExpansion(of: node)
        } else if NSEvent.modifierFlags.contains(.command) {
            onOpenInNewTab(node.url)
        } else {
            open(node.url)
        }
    }

    private func open(_ url: URL) {
        viewModel.selectedURL = url
        onSelectPDF(url)
    }
}

#Preview("Sidebar View") {
    let root = URL(fileURLWithPath: "/Users/demo/Documents/Micro 3")
    let selected = root.appendingPathComponent("Lectures/game-theory.pdf")
    let viewModel = SidebarViewModel(
        rootURL: root,
        selectedURL: selected,
        rootNodes: [
            SidebarNode(url: root.appendingPathComponent("syllabus.pdf"), isDirectory: false),
            SidebarNode(
                url: root.appendingPathComponent("Lectures"),
                isDirectory: true,
                isExpanded: true,
                children: [
                    SidebarNode(url: selected, isDirectory: false, level: 1),
                    SidebarNode(
                        url: root.appendingPathComponent("Lectures/monopoly.pdf"),
                        isDirectory: false,
                        level: 1
                    )
                ]
            )
        ]
    )

    SidebarView(viewModel: viewModel)
        .frame(width: 240, height: 500)
}
