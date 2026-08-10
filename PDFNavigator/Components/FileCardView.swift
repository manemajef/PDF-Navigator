import SwiftUI

struct FileCardView: View {
    let url: URL
    let subtitle: String?
    let action: () -> Void

    init(
        url: URL,
        subtitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.url = url
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        GalleryItemButton(action: action) {
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
        }
    }
}

#if DEBUG
#Preview("File Card Names") {
    HStack(alignment: .top, spacing: 16) {
        FileCardView(
            url: DevelopmentConfiguration.demoPDFURL,
            subtitle: "Course materials"
        )
        FileCardView(
            url: DevelopmentConfiguration.demoLongNamePDFURL,
            subtitle: "Course materials"
        )
    }
    .frame(width: 300)
    .padding()
}
#endif
