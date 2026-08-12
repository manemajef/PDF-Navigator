import SwiftUI

/// One PDF in a gallery. Draws only — it takes no actions and owns no state.
///
/// `isSelected` is pushed in by whatever presents it; the card never decides
/// that it was clicked.
struct FileCardView: View {
    let url: URL
    let subtitle: String?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ThumbnailView(url: url)

            GalleryItemLabel(
                title: url.lastPathComponent,
                subtitle: subtitle
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .gallerySelection(isSelected)
    }
}

#if DEBUG
#Preview("File Card") {
    HStack(alignment: .top, spacing: 16) {
        FileCardView(
            url: DevelopmentConfiguration.demoPDFURL,
            subtitle: "Course materials",
            isSelected: false
        )
        FileCardView(
            url: DevelopmentConfiguration.demoLongNamePDFURL,
            subtitle: "Course materials",
            isSelected: true
        )
    }
    .frame(width: 320)
    .padding()
}
#endif
