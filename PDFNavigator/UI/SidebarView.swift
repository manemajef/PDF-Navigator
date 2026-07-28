import AppKit
import SwiftUI

struct SidebarView: View {
    let nodes: [PDFTreeNode]
    let selectedPDF: URL?
    let showsFooter: Bool
    let canCreateWorkspaceTab: Bool
    let canDuplicateTab: Bool
    let onCreateWorkspaceTab: () -> Void
    let onDuplicateTab: () -> Void
    let onSelectPDF: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void
    let onExpandDirectory: (URL) -> Void

    @State private var focusedURL: URL?
    @State private var expandedDirectories: Set<URL> = []

    var body: some View {
        List(selection: $focusedURL) {
            ForEach(nodes) { node in
                SidebarTreeNodeView(
                    node: node,
                    expandedDirectories:
                        $expandedDirectories,
                    onOpenPDF: openPDF,
                    onOpenPDFInNewTab:
                        onOpenPDFInNewTab,
                    onExpandDirectory:
                        onExpandDirectory
                )
            }
        }
        .listStyle(.sidebar)
        .controlSize(.small)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsFooter {
                sidebarFooter
            }
        }
        .onAppear {
            synchronizeFocus()
        }
        .onChange(of: selectedPDF) {
            synchronizeFocus()
        }
        .onChange(of: focusedURL) {
            guard
                let focusedURL,
                let focusedNode =
                    nodes.node(matching: focusedURL),
                focusedNode.isPDF,
                case .pdf(let url) = focusedNode,
                url != selectedPDF
            else {
                return
            }

            onSelectPDF(url)
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Button(action: onCreateWorkspaceTab) {
                    Label(
                        "New Workspace Tab",
                        systemImage: "folder.badge.plus"
                    )
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("New Workspace Tab (⌘T)")
                .disabled(!canCreateWorkspaceTab)

                Button(action: onDuplicateTab) {
                    Label(
                        "Duplicate Current Tab",
                        systemImage:
                            "plus.rectangle.on.rectangle"
                    )
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Duplicate Current Tab")
                .disabled(!canDuplicateTab)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }

    private func openPDF(_ node: PDFTreeNode) {
        guard case .pdf(let url) = node else {
            return
        }

        if NSEvent.modifierFlags.contains(.command) {
            onOpenPDFInNewTab(url)

            Task {
                await Task.yield()
                synchronizeFocus()
            }
        } else {
            focusedURL = url
            onSelectPDF(url)
        }
    }

    private func synchronizeFocus() {
        guard let selectedPDF else {
            return
        }

        focusedURL =
            nodes.node(matching: selectedPDF)?.url
        expandedDirectories.formUnion(
            nodes.directoryAncestors(
                containing: selectedPDF
            )
        )
    }
}

private struct SidebarTreeNodeView: View {
    let node: PDFTreeNode

    @Binding var expandedDirectories: Set<URL>
    let onOpenPDF: (PDFTreeNode) -> Void
    let onOpenPDFInNewTab: (URL) -> Void
    let onExpandDirectory: (URL) -> Void

    @ViewBuilder
    var body: some View {
        switch node {
        case .directory(let url, let contents):
            DisclosureGroup(
                isExpanded: expansionBinding(for: url)
            ) {
                switch contents {
                case .unloaded:
                    EmptyView()
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                case .unavailable:
                    Text("Folder unavailable")
                        .foregroundStyle(.secondary)
                case .loaded(let children):
                    ForEach(children) { child in
                        SidebarTreeNodeView(
                            node: child,
                            expandedDirectories:
                                $expandedDirectories,
                            onOpenPDF: onOpenPDF,
                            onOpenPDFInNewTab:
                                onOpenPDFInNewTab,
                            onExpandDirectory:
                                onExpandDirectory
                        )
                    }
                }
            } label: {
                FinderNodeLabel(node: node)
            }
            .tag(url)

        case .pdf(let url):
            FinderNodeLabel(node: node)
                .tag(url)
                .onTapGesture {
                    onOpenPDF(node)
                }
                .contextMenu {
                    Button("Open") {
                        onOpenPDF(node)
                    }

                    Button("Open in New Tab") {
                        if case .pdf(let url) = node {
                            onOpenPDFInNewTab(url)
                        }
                    }

                    Divider()

                    Button("Show in Finder") {
                        NSWorkspace.shared
                            .activateFileViewerSelecting([
                                node.url
                            ])
                    }
                }
        }
    }

    private func expansionBinding(
        for directoryURL: URL
    ) -> Binding<Bool> {
        Binding(
            get: {
                expandedDirectories.contains(
                    directoryURL
                )
            },
            set: { isExpanded in
                if isExpanded {
                    expandedDirectories.insert(
                        directoryURL
                    )
                    onExpandDirectory(directoryURL)
                } else {
                    expandedDirectories.remove(
                        directoryURL
                    )
                }
            }
        )
    }

}

private struct FinderNodeLabel: View {
    let node: PDFTreeNode

    var body: some View {
        HStack(spacing: 6) {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: node.url.path
                )
            )
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)

            Text(node.displayName)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
