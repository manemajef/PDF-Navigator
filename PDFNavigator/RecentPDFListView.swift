import SwiftUI

final class RecentPDFListView: NSHostingView<RecentPDFListContent> {
    private var pdfs: [URL] = []

    var onOpenPDF: ((URL) -> Void)? {
        didSet { updateContent() }
    }

    init() {
        super.init(rootView: RecentPDFListContent(pdfs: [], onOpenPDF: { _ in }))
    }

    @available(*, unavailable)
    required init(rootView: RecentPDFListContent) {
        fatalError("init(rootView:) is unavailable")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func display(_ pdfs: [URL]) {
        self.pdfs = pdfs
        updateContent()
    }

    private func updateContent() {
        rootView = RecentPDFListContent(
            pdfs: pdfs,
            onOpenPDF: { [weak self] url in self?.onOpenPDF?(url) }
        )
    }
}

struct RecentPDFListContent: View {
    let pdfs: [URL]
    let onOpenPDF: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent PDFs")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 2) {
                if pdfs.isEmpty {
                    Text("No recent PDFs.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    ForEach(pdfs, id: \.self) { url in
                        Button {
                            onOpenPDF(url)
                        } label: {
                            RecentPDFRow(url: url)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(6)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecentPDFRow: View {
    let url: URL
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13))
                    .truncationMode(.middle)
                    .lineLimit(1)

                Text((url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}


