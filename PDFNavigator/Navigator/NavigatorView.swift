import AppKit
import SwiftUI

struct NavigatorView: View {
    let nodes: [PDFTreeNode]
    let selectedPDF: URL?
    let canCreateWorkspaceTab: Bool
    let canDuplicateTab: Bool
    let onCreateWorkspaceTab: () -> Void
    let onDuplicateTab: () -> Void
    let onSelectPDF: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void

    @State private var focusedNode: PDFTreeNode?
    @State private var expandedDirectories: Set<URL> = []

    var body: some View {
        List(selection: $focusedNode) {
            ForEach(nodes) { node in
                NavigatorTreeNodeView(
                    node: node,
                    expandedDirectories:
                        $expandedDirectories,
                    onOpenPDF: openPDF,
                    onOpenPDFInNewTab:
                        onOpenPDFInNewTab
                )
            }
        }
        .listStyle(.sidebar)
        .controlSize(.small)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarActions
        }
        .onAppear {
            synchronizeFocus()
        }
        .onChange(of: selectedPDF) {
            synchronizeFocus()
        }
        .onChange(of: focusedNode) {
            guard
                let focusedNode,
                case .pdf(let url) = focusedNode,
                url != selectedPDF
            else {
                return
            }

            onSelectPDF(url)
        }
    }

    private var sidebarActions: some View {
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

            DispatchQueue.main.async {
                synchronizeFocus()
            }
        } else {
            focusedNode = node
            onSelectPDF(url)
        }
    }

    private func synchronizeFocus() {
        guard let selectedPDF else {
            return
        }

        focusedNode = findNode(
            matching: selectedPDF,
            in: nodes
        )
        expandedDirectories.formUnion(
            directoryAncestors(
                containing: selectedPDF,
                in: nodes
            )
        )
    }

    private func findNode(
        matching url: URL,
        in nodes: [PDFTreeNode]
    ) -> PDFTreeNode? {
        for node in nodes {
            if node.url == url {
                return node
            }

            if
                let children = node.children,
                let match = findNode(
                    matching: url,
                    in: children
                )
            {
                return match
            }
        }

        return nil
    }

    private func directoryAncestors(
        containing selectedPDF: URL,
        in nodes: [PDFTreeNode]
    ) -> Set<URL> {
        for node in nodes {
            switch node {
            case .pdf(let url):
                if url == selectedPDF {
                    return []
                }

            case .directory(let url, let children):
                if findNode(
                    matching: selectedPDF,
                    in: children
                ) != nil {
                    return Set([
                        url
                    ]).union(
                        directoryAncestors(
                            containing: selectedPDF,
                            in: children
                        )
                    )
                }
            }
        }

        return []
    }
}

private struct NavigatorTreeNodeView: View {
    let node: PDFTreeNode

    @Binding var expandedDirectories: Set<URL>
    let onOpenPDF: (PDFTreeNode) -> Void
    let onOpenPDFInNewTab: (URL) -> Void

    @ViewBuilder
    var body: some View {
        switch node {
        case .directory(let url, let children):
            DisclosureGroup(
                isExpanded: expansionBinding(for: url)
            ) {
                ForEach(children) { child in
                    NavigatorTreeNodeView(
                        node: child,
                        expandedDirectories:
                            $expandedDirectories,
                        onOpenPDF: onOpenPDF,
                        onOpenPDFInNewTab:
                            onOpenPDFInNewTab
                    )
                }
            } label: {
                FinderNodeLabel(node: node)
            }
            .tag(node)

        case .pdf:
            FinderNodeLabel(node: node)
                .tag(node)
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
