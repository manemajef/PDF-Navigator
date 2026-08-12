import SwiftUI

/// The workspace-scoped page shown when the user creates a new tab.
struct StartPageView: View {
    let recentURLs: [URL]
    let onOpenPDF: (URL) -> Void
    let onOpenPDFInNewTab: (URL) -> Void
    let onRevealInFinder: (URL) -> Void

    var body: some View {
        RecentPDFGridView(
            urls: recentURLs,
            onOpenPDF: onOpenPDF,
            onOpenPDFInNewTab: onOpenPDFInNewTab,
            onRevealInFinder: onRevealInFinder
        )
    }
}

#if DEBUG
#Preview("Start Page") {
    @Previewable @State var text = ""
    NavigationSplitView{}detail: {
        StartPageView(
            recentURLs: DevelopmentConfiguration.loadPDFs(limit: 12),
            onOpenPDF: { _ in },
            onOpenPDFInNewTab: { _ in },
            onRevealInFinder: { _ in }
        )
    }
    .toolbar{
        ToolbarItem{
            Button(action: {}){
                Label("", systemImage: "plus")
            }
        }
        
    }
    .searchable(text: $text)
    .frame(width: 600, height: 620)
    


}
#endif
