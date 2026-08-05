import SwiftUI
import AppKit
import QuickLookThumbnailing
let USE_HSTACK = false
let THUMB_WIDTH = USE_HSTACK ? 40 :  180.0
let THUM_HEIGHT = USE_HSTACK ? 52 : THUMB_WIDTH * 1.4
let STACK_SPACING = USE_HSTACK ? 12 : 2


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
        let layout = USE_HSTACK ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 2))
        Button(action: action) {
            /// for alternative compact look use :
            /// - `HStack` with spacing `12`
            /// - set THUMB_WIDTH = 40 and THUMB_HEIGHT = 52
            layout {
                PDFThumbnailView(url: url)

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if USE_HSTACK {
                    Spacer(minLength: 0)
                    
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: USE_HSTACK ? .leading : .center)
        }
        .buttonStyle(.hover(cornerRadius: 10))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
//        .padding()
    }
}

private struct PDFThumbnailView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var image: NSImage?
    
    let url: URL
    
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc.text.fill")
//                    .font(.system(size:)
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
        .frame(width: THUMB_WIDTH, height: THUM_HEIGHT)
        .task(id: url) {
            image = nil
            
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: THUMB_WIDTH, height: THUM_HEIGHT),
                scale: displayScale,
                representationTypes: .thumbnail
            )
            request.iconMode = true
            
            guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request),
                  !Task.isCancelled
            else {
                return
            }
            image = representation.nsImage
        }
    }
}

#Preview("File Card") {
    FileCardView(url: DevelopmentConfiguration.demoPDFURL, action: {})
}
