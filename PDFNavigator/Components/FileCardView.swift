import SwiftUI

struct FileCardView: View {
    let url: URL
    let subtitle: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    
    var body: some View {
        GalleryItemView(
            isSelected: isSelected,
            onSelect: onSelect,
            onOpen: onOpen
        ){
            VStack(spacing: 2){
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
            subtitle: "Course materials",
            isSelected: false,
            onSelect: {},
            onOpen: {}
        )
        FileCardView(
            url: DevelopmentConfiguration.demoLongNamePDFURL,
            subtitle: "Course materials",
            isSelected: true,
            onSelect: {},
            onOpen: {}
        )
    }
    .frame(width: 300)
    .padding()
}
#endif
