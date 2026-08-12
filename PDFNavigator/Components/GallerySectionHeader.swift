import SwiftUI

/// The title above one gallery section.
struct GallerySectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("(\(count))")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview("Section Header") {
    VStack(alignment: .leading, spacing: 12) {
        GallerySectionHeader(title: "Folders", count: 4)
        GallerySectionHeader(title: "PDFs", count: 128)
    }
    .padding()
    .frame(width: 320)
}
#endif
