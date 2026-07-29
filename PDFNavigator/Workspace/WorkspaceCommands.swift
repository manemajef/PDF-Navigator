import PDFKit
import SwiftUI

struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Workspace Tab") {
                actions?.createTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(actions?.canCreateTab != true)

            Button("Duplicate Current Tab") {
                actions?.duplicateTab()
            }
            .disabled(actions?.canDuplicateTab != true)
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

        CommandMenu("PDF") {
            Button("Zoom In") {
                pdfView?.autoScales = false
                pdfView?.zoomIn(nil)
            }
                .disabled(pdfView?.canZoomIn != true)

            Button("Zoom Out") {
                pdfView?.autoScales = false
                pdfView?.zoomOut(nil)
            }
                .disabled(pdfView?.canZoomOut != true)

            Button("Actual Size") {
                pdfView?.showPrintSize()
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(pdfView?.document == nil)

            Button("Zoom to Fit") {
                guard let pdfView else { return }
                pdfView.autoScales = true
            }
            .disabled(pdfView?.document == nil)
        }
    }

    private var pdfView: PDFView? {
        actions?.reader.view
    }
}
