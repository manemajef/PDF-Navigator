import SwiftUI

/// The workspace-scoped page shown when the user creates a new tab.
struct StartPageView: View {
    let recentURLs: [URL]
    let onSelectPDF: (URL) -> Void

    var body: some View {
        ScrollView {
            RecentPDFGridView(
                urls: recentURLs,
                onSelectPDF: onSelectPDF
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
    StartPageView(
        recentURLs: DevelopmentConfiguration.loadPDFs(limit: 12),
        onSelectPDF: { _ in }
    )
    .frame(width: 700, height: 620)
}
#endif
