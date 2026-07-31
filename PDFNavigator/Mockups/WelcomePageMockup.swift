import SwiftUI
import AppKit

// MARK: - Fake Data

private struct MockPDF: Identifiable {
    let id = UUID()
    let name: String
    let folder: String
    let lastOpened: String
}

private struct MockFolder: Identifiable {
    let id = UUID()
    let name: String
    let lastOpened: String
}

private enum MockData {
    static let recents: [MockPDF] = [
        .init(name: "micro3-syllabus.pdf", folder: "University/Micro 3", lastOpened: "2h ago"),
        .init(name: "linear-algebra-notes.pdf", folder: "University/Linear Algebra", lastOpened: "yesterday"),
        .init(name: "a-very-long-paper-title-that-should-truncate-in-the-middle.pdf", folder: "Papers/To Read", lastOpened: "2d ago"),
        .init(name: "apartment-lease.pdf", folder: "Documents/Home", lastOpened: "last week"),
        .init(name: "swift-evolution-proposal.pdf", folder: "Papers", lastOpened: "3w ago")
    ]

    static let folderRecents: [MockPDF] = [
        .init(name: "micro3-syllabus.pdf", folder: "Micro 3", lastOpened: "2h ago"),
        .init(name: "problem-set-4.pdf", folder: "Micro 3/Problem Sets", lastOpened: "yesterday"),
        .init(name: "lecture-07-game-theory.pdf", folder: "Micro 3/Lectures", lastOpened: "3d ago"),
        .init(name: "midterm-2019-solutions.pdf", folder: "Micro 3/Exams", lastOpened: "last week")
    ]
    
    static let recentFolders: [MockFolder] = [
        .init(name: "Micro 3", lastOpened: "2h ago"),
        .init(name: "Problem sets", lastOpened: "1 day ago"),
        .init(name: "Documents", lastOpened: "2 days ago"),
        .init(name: "Exams", lastOpened: "3 days ago")
    ]
}

private let pageBackground = Color(nsColor: .windowBackgroundColor)

// MARK: - Welcome Page

private struct WelcomeMockup: View {
    let recents: [MockPDF]
    let folders: [MockFolder]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text("PDF Navigator")
                        .font(.system(size: 26, weight: .bold))

                    Text("Open a PDF or folder to begin.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Button("Open…") {}
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 4)
                }

                // Recent Workspaces & PDFs Container
                VStack(spacing: 16) {
                    if !folders.isEmpty {
                        FolderRow(mockFolders: folders)
                    }
                    
                    recentsSection
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
    }

    @ViewBuilder
    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent PDFs")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 2) {
                if recents.isEmpty {
                    Text("No recent PDFs.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(recents) { pdf in
                        RecentRow(pdf: pdf)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quinary)
            )
        }
        .frame(maxWidth: 440)
    }
}

// MARK: - Folder Page

private struct FolderMockup: View {
    let folderName: String
    let folderPath: String
    let recents: [MockPDF]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 40)
                .padding(.top, 48)
                .padding(.bottom, 24)

            Divider()
                .padding(.horizontal, 40)
            
            recentsGrid
                .padding(40)

            Spacer(minLength: 0)

            Text("Browse all files in the sidebar.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pageBackground)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor.gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(folderName)
                    .font(.system(size: 22, weight: .semibold))
                Text(folderPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
            }

            Spacer()

            Button("Open Different…") {}
                .controlSize(.regular)
        }
    }

    private var recentsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent in \(folderName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(recents) { pdf in
                    FileCard(pdf: pdf)
                }
            }
        }
    }
}

// MARK: - Helper Components

private struct FolderCard: View {
    let folder: MockFolder
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.accentColor.gradient)
                
                Text(folder.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .top)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .frame(width: 88)
        .onHover { isHovered = $0 }
        .contextMenu {
            Text("Last opened \(folder.lastOpened)")
        }
    }
}

private struct FolderRow: View {
    let mockFolders: [MockFolder]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Folders")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(mockFolders) { folder in
                        FolderCard(folder: folder)
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: false, vertical: true)
//            .background(
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(.quinary)
//            )
        }
        .frame(maxWidth: 440)
    }
}

private struct RecentRow: View {
    let pdf: MockPDF
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(pdf.name)
                    .font(.system(size: 13))
                    .truncationMode(.middle)
                    .lineLimit(1)
                Text(pdf.folder)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(pdf.lastOpened)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

private struct FileCard: View {
    let pdf: MockPDF
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red.opacity(0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(pdf.name)
                    .font(.system(size: 12, weight: .medium))
                    .truncationMode(.middle)
                    .lineLimit(1)
                Text(pdf.lastOpened)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.quinary))
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Previews

#Preview("Welcome — with recents") {
    WelcomeMockup(recents: MockData.recents, folders: MockData.recentFolders)
        .frame(width: 700, height: 750)
}

#Preview("Folder page") {
    FolderMockup(
        folderName: "Micro 3",
        folderPath: "~/University/Semester 4/Micro 3",
        recents: MockData.folderRecents
    )
    .frame(width: 700, height: 750)
}
