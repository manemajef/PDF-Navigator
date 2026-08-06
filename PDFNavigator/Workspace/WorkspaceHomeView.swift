import SwiftUI

struct WorkspaceHomeView: View {
    let folderURL: URL
    let pdfURLs: [URL]
    let onOpenDifferent: () -> Void
    let onSelectPDF: (URL) -> Void

    init(
        folderURL: URL,
        pdfURLs: [URL] = [],
        onOpenDifferent: @escaping () -> Void = {},
        onSelectPDF: @escaping (URL) -> Void = { _ in }
    ) {
        self.folderURL = folderURL
        self.pdfURLs = pdfURLs
        self.onOpenDifferent = onOpenDifferent
        self.onSelectPDF = onSelectPDF
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkspaceHeaderView(
                folderName: folderURL.lastPathComponent,
                folderPath: folderURL.path,
                onOpenDifferent: onOpenDifferent
            )
            .padding(.horizontal, 36)
            .padding(.top, 40)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 36)

            ScrollView {
                FileCardGridView(
                    pdfURLs: pdfURLs,
                    onSelectPDF: onSelectPDF
                )
                .padding()
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("Select a file to start reading, or browse all files in the sidebar.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Workspace Home View") {
    WorkspaceHomeView(
        folderURL:                 DevelopmentConfiguration.demoDirURL
,
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
    .frame(width: 700, height: 600)
}
