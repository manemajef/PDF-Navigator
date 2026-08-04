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
            Text("Workspace Files")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if pdfURLs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No PDF files found in this workspace folder.")
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
                            title: url.lastPathComponent,
                            subtitle: url.deletingLastPathComponent().lastPathComponent,
                            action: { onSelectPDF(url) }
                        )
                    }
                }
            }
        }
    }
}

#Preview("File Card Grid View") {
    FileCardGridView(
        pdfURLs: [
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3/syllabus.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3/lecture-1.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3/problem-set-1.pdf"),
            URL(fileURLWithPath: "/Users/demo/Documents/Micro 3/midterm-review.pdf")
        ]
    )
    .padding(24)
    .frame(width: 650)
}
