import SwiftUI

/// Shown in place of the gallery when a folder holds nothing to display.
struct GalleryEmptyState: View {
    let symbolName: String
    let message: String

    init(symbolName: String = "doc.text.magnifyingglass", message: String) {
        self.symbolName = symbolName
        self.message = message
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Empty State") {
    GalleryEmptyState(message: "This workspace has no PDFs yet")
        .frame(width: 500, height: 300)
}
#endif
