import Foundation

struct DirectoryScanner {
    @concurrent
    static func items(in directory: URL) async throws -> [NavigatorItem] {
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

        var items: [NavigatorItem] = []
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
                items.append(NavigatorItem(url: url, isDirectory: true))
            } else if values.isRegularFile == true,
                      url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
                items.append(NavigatorItem(url: url, isDirectory: false))
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
