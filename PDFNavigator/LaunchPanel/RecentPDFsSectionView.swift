import SwiftUI

struct RecentPDFsSectionView: View {
    let pdfURLs: [URL]
    let onSelectPDF: (URL) -> Void

    init(
        pdfURLs: [URL] = [],
        onSelectPDF: @escaping (URL) -> Void = { _ in }
    ) {
        self.pdfURLs = pdfURLs
        self.onSelectPDF = onSelectPDF
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent PDFs")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 2) {
                if pdfURLs.isEmpty {
                    Text("No recent PDFs.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: 20, minHeight: 60)
                } else {
                    ForEach(pdfURLs, id: \.self) { url in
                        RecentRowView(
                            title: url.lastPathComponent,
                            subtitle: url.deletingLastPathComponent().lastPathComponent,
                            action: { onSelectPDF(url) }
                        )
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

#Preview("Recent PDFs Section") {
    RecentPDFsSectionView(
        pdfURLs: [
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3/syllabus.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/Linear Algebra/notes.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/apartment-lease.pdf")
        ]
    )
    .padding(20)
}
