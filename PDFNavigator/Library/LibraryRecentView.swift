import SwiftUI

// MARK: - Library Tab Enum


// MARK: - Library View

struct LibraryRecentView: View {
    let folderURL: URL
    let folderURLs: [URL]
    let libraryPDFURLs: [URL]
    let recentPDFURLs: [URL]
    let onOpenDifferent: () -> Void
    let onSelectPDF: (URL) -> Void
    let onSelectFolder: (URL) -> Void

    @State private var selectedTab: LibraryTab = .library

    init(
        folderURL: URL,
        folderURLs: [URL] = [],
        pdfURLs: [URL] = [],
        recentPDFURLs: [URL]? = nil,
        onOpenDifferent: @escaping () -> Void = {},
        onSelectPDF: @escaping (URL) -> Void = { _ in },
        onSelectFolder: @escaping (URL) -> Void = { _ in }
    ) {
        self.folderURL = folderURL
        self.folderURLs = folderURLs
        self.libraryPDFURLs = pdfURLs
        self.recentPDFURLs = recentPDFURLs ?? pdfURLs
        self.onOpenDifferent = onOpenDifferent
        self.onSelectPDF = onSelectPDF
        self.onSelectFolder = onSelectFolder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Title and Tabbed Segmented Switcher
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(folderDisplayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(folderURL.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Picker("Library View", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
//                .frame(width: 190)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 28)
                .padding(.bottom, 8)

            // Tab Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .library:
                        LibraryGridView(
                            folderURLs: folderURLs,
                            pdfURLs: libraryPDFURLs,
                            onSelectPDF: onSelectPDF,
                            onSelectFolder: onSelectFolder
                        )

                    case .recents:
                        LibraryGridView(
                            folderURLs: [],
                            pdfURLs: recentPDFURLs,
                            onSelectPDF: onSelectPDF,
                            onSelectFolder: onSelectFolder
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
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

    private var folderDisplayName: String {
        folderURL.lastPathComponent.isEmpty ? folderURL.path : folderURL.lastPathComponent
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Demo_Dir") {
    @Previewable @State  var searchText: String = ""

    if #available(macOS 26.0, *) {
        NavigationSplitView{
            
        } detail: {
            LibraryRecentView(
                folderURL: DevelopmentConfiguration.demoDirURL,
                folderURLs: DevelopmentConfiguration.demoFolderURLs,
                pdfURLs: DevelopmentConfiguration.loadPDFs(recursive: false),
                recentPDFURLs: DevelopmentConfiguration.loadPDFs(limit: 8)
            )
            
        }
        
            .frame(width: 700, height: 620)
        .toolbar{
           
            
            ToolbarItem{
                ControlGroup{
                    Button(action: {}){
                        Text("Recent")
                    }
                    Button(action: {}){
                        Text("Browse")
                    }
                }
                .controlGroupStyle(.navigation)
            }
            ToolbarItem{
                Button(action: {}){
                    Label("New", systemImage: "plus")
                }
            }
        }
        .searchable(text: $searchText)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar(removing: .title)

    } else {
        // Fallback on earlier versions
    }
}
#endif

