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

    @concurrent
    static func items(
        from root: URL,
        revealing file: URL?
    ) async throws -> [URL: [NavigatorItem]] {
        let root = root.standardizedFileURL
        var result = [root: try await items(in: root)]

        guard let file else { return result }

        let parent = file.standardizedFileURL.deletingLastPathComponent()
        let rootParts = root.pathComponents
        let parentParts = parent.pathComponents
        guard parentParts.starts(with: rootParts) else { return result }

        var directory = root
        for component in parentParts.dropFirst(rootParts.count) {
            directory.appendPathComponent(component, isDirectory: true)
            result[directory] = try await items(in: directory)
        }

        return result
    }
}
