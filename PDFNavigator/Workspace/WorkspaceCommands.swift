import AppKit
import PDFKit
import SwiftUI

struct WorkspaceCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.workspaceActions) private var actions
    @ObservedObject private var recentDocuments = RecentDocuments.shared
    private let openWorkspaceWithAppKit: ((WorkspaceLaunch) -> Void)?

    init(
        openWorkspaceWithAppKit: ((WorkspaceLaunch) -> Void)? = nil
    ) {
        self.openWorkspaceWithAppKit = openWorkspaceWithAppKit
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWorkspace(WorkspaceLaunch.emptyWindow)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Workspace Tab") {
                if actions?.canCreateTab == true {
                    actions?.createTab()
                } else {
                    openWorkspace(.emptyWindow)
                }
            }
            .keyboardShortcut("t", modifiers: .command)

            Menu("Open Recent") {
                if recentDocuments.urls.isEmpty {
                    Button("No Recent Files") {}
                        .disabled(true)
                } else {
                    ForEach(recentDocuments.urls, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            openRecent(url)
                        }
                    }

                    Divider()

                    Button("Clear Menu") {
                        recentDocuments.clear()
                    }
                }
            }

            Divider()

            Button("Replace Workspace…") {
                actions?.replaceWorkspace()
            }
            .disabled(actions == nil)

            Button("Open in Default App") {
                if let pdf = actions?.session.selectedPDF {
                    NSWorkspace.shared.open(pdf)
                }
            }
            .disabled(actions?.session.selectedPDF == nil)
        }

        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") {
                NSApp.sendAction(
                    #selector(NSSplitViewController.toggleSidebar(_:)),
                    to: nil,
                    from: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .toolbar) {
            Button("Toggle Toolbar") {
                actions?.toggleToolbar()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(actions == nil)
        }

        CommandGroup(after: .importExport) {
            Button("Share…") {
                guard let pdf = actions?.session.selectedPDF,
                      let pdfView else {
                    return
                }
                NSSharingServicePicker(items: [pdf]).show(
                    relativeTo: pdfView.bounds,
                    of: pdfView,
                    preferredEdge: .maxY
                )
            }
            .disabled(actions?.session.selectedPDF == nil || pdfView == nil)
        }

        CommandMenu("Navigate") {
            Button("Back") { actions?.session.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(actions?.session.canGoBack != true)

            Button("Forward") { actions?.session.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(actions?.session.canGoForward != true)

            Divider()

            Button("Previous PDF Page") {
                pdfView?.goToPreviousPage(nil)
            }
            .disabled(pdfView?.canGoToPreviousPage != true)

            Button("Next PDF Page") {
                pdfView?.goToNextPage(nil)
            }
            .disabled(pdfView?.canGoToNextPage != true)

            Button("Back in PDF") {
                pdfView?.goBack(nil)
            }
            .disabled(pdfView?.canGoBack != true)

            Button("Forward in PDF") {
                pdfView?.goForward(nil)
            }
            .disabled(pdfView?.canGoForward != true)
        }

        CommandGroup(after: .sidebar) {
            Button("Actual Size") {
                pdfView?.showPrintSize()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(pdfView?.document == nil)

            Button("Zoom to Fit") {
                pdfView?.autoScales = true
            }
            .keyboardShortcut("9", modifiers: .command)
            .disabled(pdfView?.document == nil)

            Divider()

            Button("Zoom In") {
                pdfView?.autoScales = false
                pdfView?.zoomIn(nil)
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(pdfView?.canZoomIn != true)

            Button("Zoom Out") {
                pdfView?.autoScales = false
                pdfView?.zoomOut(nil)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(pdfView?.canZoomOut != true)

            Button("Zoom to Selection") {
                pdfView?.zoomToCurrentSelection()
            }
            .keyboardShortcut("*", modifiers: .command)
            .disabled(pdfView?.currentSelection?.pages.isEmpty != false)
        }
    }

    private var pdfView: PDFView? {
        actions?.reader.view
    }

    private func openRecent(_ url: URL) {
        recentDocuments.note(url)
        openWorkspace(
            WorkspaceLaunch.openingPDF(
                rootURL: url.deletingLastPathComponent(),
                selectedPDF: url
            )
        )
    }

    private func openWorkspace(_ launch: WorkspaceLaunch) {
        if let openWorkspaceWithAppKit {
            openWorkspaceWithAppKit(launch)
        } else {
            openWindow(value: launch)
        }
    }
}
