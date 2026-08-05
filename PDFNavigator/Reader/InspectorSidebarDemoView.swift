import SwiftUI

#if DEBUG
struct InspectorSidebarDemoView: View {
    enum Section: String, CaseIterable, Identifiable {
        case thumbnails
        case contents
        case info

        var id: Self { self }

        var title: String {
            switch self {
            case .thumbnails: "Thumbnails"
            case .contents: "Contents"
            case .info: "Info"
            }
        }

        var symbol: String {
            switch self {
            case .thumbnails: "square.grid.2x2"
            case .contents: "list.bullet.indent"
            case .info: "info.circle"
            }
        }
    }

    let fileName: String
    let pageCount: Int
    let onSelectPage: (Int) -> Void

    init(
        fileName: String,
        pageCount: Int,
        onSelectPage: @escaping (Int) -> Void = { _ in }
    ) {
        self.fileName = fileName
        self.pageCount = pageCount
        self.onSelectPage = onSelectPage
    }

    @State private var section = Section.thumbnails

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $section) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .labelStyle(.iconOnly)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(section.title)
            .padding(10)

            Divider()

            switch section {
            case .thumbnails:
                thumbnails
            case .contents:
                contents
            case .info:
                info
            }
        }
        .frame(minWidth: 180, idealWidth: 240)
    }

    private var thumbnails: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(0..<demoPageCount, id: \.self) { pageIndex in
                    Button {
                        onSelectPage(pageIndex)
                    } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.background)
                                .aspectRatio(0.72, contentMode: .fit)
                                .overlay {
                                    Image(systemName: "doc.richtext")
                                        .font(.title)
                                        .foregroundStyle(.tertiary)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.separator, lineWidth: 1)
                                }

                            Text("Page \(pageIndex + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .help("Go to page \(pageIndex + 1)")
                }
            }
            .padding(14)
        }
    }

    private var contents: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.indent")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Table of Contents")
                .font(.headline)
            Text("The production version will show the PDF outline here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var info: some View {
        Form {
            LabeledContent("File", value: fileName)
            LabeledContent("Pages", value: "\(pageCount)")
        }
        .formStyle(.grouped)
    }

    private var demoPageCount: Int {
        min(max(pageCount, 1), 12)
    }
}

#Preview("Inspector Sidebar Demo") {
    InspectorSidebarDemoView(
        fileName: "micro3-syllabus.pdf",
        pageCount: 18
    )
    .frame(width: 240, height: 620)
}
#endif
