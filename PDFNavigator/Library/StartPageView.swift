import SwiftUI

/// The workspace-scoped page shown when the user creates a new tab.
struct StartPageView: View {
    let recentURLs: [URL]
    let onOpenPDF: (URL) -> Void

    var body: some View {
        ScrollView {
            RecentPDFGridView(
                urls: recentURLs,
                onOpenPDF: onOpenPDF
            )
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Start Page") {
    @Previewable @State var text = ""
    NavigationSplitView{}detail: {
        StartPageView(
            recentURLs: DevelopmentConfiguration.loadPDFs(limit: 12),
            onOpenPDF: { _ in }
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
