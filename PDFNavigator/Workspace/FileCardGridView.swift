import SwiftUI

struct FileCardGridView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent PDF's")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if pdfURLs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No recently opened PDF's in this workspace")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(pdfURLs, id: \.self) { url in
                        FileCardView(
                            url: url,
                            subtitle: url.deletingLastPathComponent().lastPathComponent,
                            action: { onSelectPDF(url) }
                        )
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("File Card Grid View") {
    FileCardGridView(
        pdfURLs: [
            DevelopmentConfiguration.demoPDFURL,
            DevelopmentConfiguration.demoDirURL
                .appendingPathComponent("lecs/micro3-lec-1.pdf"),
            DevelopmentConfiguration.demoDirURL
                .appendingPathComponent("hw/micro3-hw-1.pdf"),
            DevelopmentConfiguration.demoDirURL
                .appendingPathComponent("exams/micro3-exam-2026-a1.pdf")
        ]
    )
    .padding(24)
    .frame(width: 650)
}
#endif
