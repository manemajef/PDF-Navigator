import Foundation

#if DEBUG
nonisolated enum DevelopmentConfiguration {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let demoDirURL = repositoryRoot
        .appendingPathComponent("DEMO_DIR", isDirectory: true)
    static let demoPDFURL = demoDirURL
        .appendingPathComponent("micro3-sylabus.pdf")
    static let demoLongNamePDFURL = demoDirURL
        .appendingPathComponent("נספח חישובים עבור שיעור בית.pdf")
    /// Synthetic path used only to exercise folder-label truncation in previews.
    static let demoLongNameFolderURL = demoDirURL
        .appendingPathComponent(
            "Homework exercises, solutions, and reference material",
            isDirectory: true
        )
    static let demoOutlinePDFURL = demoDirURL
        .appendingPathComponent("lecs/micro3-lec-8b.pdf")

    static var demoFolderURLs: [URL] {
        DirectoryScanner.items(in: demoDirURL)
            .filter(\.isDirectory)
            .map(\.url)
    }

    static func loadPDFs(
        from directory: URL = demoDirURL,
        limit: Int? = nil,
        recursive: Bool = true
    ) -> [URL] {
        let urls: [URL]
        if recursive {
            urls = (FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )?.allObjects as? [URL] ?? [])
                .filter { $0.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame }
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        } else {
            urls = DirectoryScanner.items(in: directory)
                .filter { !$0.isDirectory }
                .map(\.url)
        }

        guard let limit else { return urls }
        return Array(urls.prefix(max(0, limit)))
    }
}
#endif
