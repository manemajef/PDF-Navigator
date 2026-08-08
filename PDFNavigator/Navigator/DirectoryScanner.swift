import Foundation

struct DirectoryScanner {
    struct Item: Sendable {
        let url: URL
        let isDirectory: Bool

        nonisolated var name: String { url.lastPathComponent }
    }

    @concurrent
    static func items(in directory: URL) async throws -> [Item] {
        try Task.checkCancellation()

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var items: [Item] = []
        for url in urls {
            try Task.checkCancellation()

            guard let values = try? url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]), values.isSymbolicLink != true else {
                continue
            }

            if values.isDirectory == true {
                items.append(Item(url: url, isDirectory: true))
            } else if values.isRegularFile == true,
                      url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
                items.append(Item(url: url, isDirectory: false))
            }
        }

        return items.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
