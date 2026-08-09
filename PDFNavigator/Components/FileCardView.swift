import SwiftUI
import AppKit
import QuickLookThumbnailing
let USE_HSTACK = false
let THUMB_WIDTH = USE_HSTACK ? 40 :  120.0
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
        Button(action: action){
            /// for alternative compact look use :
            /// - `HStack` with spacing `12`
            /// - set THUMB_WIDTH = 40 and THUMB_HEIGHT = 52
            layout {
                ThumbnailView(
                    url: url,
                    size: CGSize(width: THUMB_WIDTH, height: THUM_HEIGHT)
                )

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
        .buttonStyle(.plain)
    }
}

#if DEBUG
    #Preview("File Card") {
        FileCardView(url: DevelopmentConfiguration.demoPDFURL, action: {})
    }
#endif
