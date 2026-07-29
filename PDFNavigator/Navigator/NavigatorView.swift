import AppKit
import SwiftUI

struct NavigatorView: View {
    @ObservedObject var session: WorkspaceSession
    let onSelectPDF: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void

    @State private var focusedURL: URL?
    @State private var expandedDirectories: Set<URL> = []

    var body: some View {
        List(selection: $focusedURL) {
            ForEach(session.items) { item in
                NavigatorRow(
                    item: item,
                    session: session,
                    expandedDirectories: $expandedDirectories,
                    onOpenPDF: openPDF,
                    onOpenPDFInNewTab: onOpenPDFInNewTab
                )
            }
        }
        .listStyle(.sidebar)
        .environment(\.sidebarRowSize, .small)
        .onAppear(perform: synchronizeSelection)
        .onChange(of: session.selectedPDF) {
            synchronizeSelection()
        }
        .onChange(of: focusedURL) {
            guard !NSEvent.modifierFlags.contains(.command) else { return }
            if let focusedURL,
               focusedURL.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame,
               focusedURL != session.selectedPDF {
                onSelectPDF(focusedURL)
            }
        }
    }

    private func openPDF(_ url: URL) {
        if NSEvent.modifierFlags.contains(.command) {
            onOpenPDFInNewTab(url)
            Task {
                await Task.yield()
                synchronizeSelection()
            }
        } else {
            focusedURL = url
            onSelectPDF(url)
        }
    }

    private func synchronizeSelection() {
        guard let pdf = session.selectedPDF else {
            focusedURL = nil
            return
        }

        focusedURL = pdf
        expandedDirectories.formUnion(ancestors(of: pdf))
    }

    private func ancestors(of file: URL) -> [URL] {
        guard let root = session.rootURL else { return [] }

        let rootParts = root.pathComponents
        let parentParts = file.deletingLastPathComponent().pathComponents
        guard parentParts.starts(with: rootParts) else { return [] }

        var result: [URL] = []
        var directory = root
        for component in parentParts.dropFirst(rootParts.count) {
            directory.appendPathComponent(component, isDirectory: true)
            result.append(directory)
        }
        return result
    }
}

private struct NavigatorRow: View {
    let item: NavigatorItem
    @ObservedObject var session: WorkspaceSession
    @Binding var expandedDirectories: Set<URL>
    let onOpenPDF: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void

    @ViewBuilder
    var body: some View {
        if item.isDirectory {
            DisclosureGroup(isExpanded: expansion) {
                if let children = session.items(in: item.url) {
                    ForEach(children) { child in
                        NavigatorRow(
                            item: child,
                            session: session,
                            expandedDirectories: $expandedDirectories,
                            onOpenPDF: onOpenPDF,
                            onOpenPDFInNewTab: onOpenPDFInNewTab
                        )
                    }
                } else if session.isLoading(item.url) {
                    ProgressView()
                        .controlSize(.small)
                }
            } label: {
                FileLabel(item: item)
            }
            .tag(item.url)
        } else {
            FileLabel(item: item)
                .tag(item.url)
                .onTapGesture { onOpenPDF(item.url) }
                .contextMenu {
                    Button("Open") { onOpenPDF(item.url) }
                    Button("Open in New Tab") { onOpenPDFInNewTab(item.url) }
                    Divider()
                    Button("Open in Default App") {
                        NSWorkspace.shared.open(item.url)
                    }
                    ShareLink(item: item.url)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                }
        }
    }

    private var expansion: Binding<Bool> {
        Binding {
            expandedDirectories.contains(item.url)
        } set: { isExpanded in
            if isExpanded {
                expandedDirectories.insert(item.url)
                session.expand(item.url)
            } else {
                expandedDirectories.remove(item.url)
            }
        }
    }
}

private struct FileLabel: View {
    let item: NavigatorItem

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text(item.name).lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.body)
        .contentShape(Rectangle())
    }
}
