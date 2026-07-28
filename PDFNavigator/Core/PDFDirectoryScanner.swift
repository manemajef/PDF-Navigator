import Foundation

struct PDFDirectoryScanner {
    @concurrent
    static func scan(directory: URL) async throws
        -> [PDFTreeNode] {
        try scanLevel(directory: directory)
    }

    @concurrent
    static func scan(
        directory: URL,
        revealing pdf: URL
    ) async throws -> [PDFTreeNode] {
        var nodes = try scanLevel(directory: directory)
        let parent = pdf.deletingLastPathComponent()

        guard parent != directory else {
            return nodes
        }

        let relativePath = parent.path(
            percentEncoded: false
        )
        .dropFirst(
            directory.path(percentEncoded: false).count
        )
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var currentDirectory = directory
        for component in relativePath.split(separator: "/") {
            try Task.checkCancellation()
            currentDirectory.append(
                component: String(component),
                directoryHint: .isDirectory
            )
            let children = try scanLevel(
                directory: currentDirectory
            )
            nodes = nodes.replacingDirectoryContents(
                at: currentDirectory,
                with: .loaded(children),
            )
        }

        return nodes
    }

    nonisolated private static func scanLevel(
        directory: URL
    ) throws -> [PDFTreeNode] {
        try Task.checkCancellation()

        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [
                .skipsHiddenFiles,
                .skipsPackageDescendants
            ]
        )
        .compactMap(makeNode)
        .sorted(by: sortsBefore)
    }

    nonisolated private static func makeNode(
        for url: URL
    ) -> PDFTreeNode? {
        guard let values = try? url.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        ), values.isSymbolicLink != true else {
            return nil
        }

        if values.isDirectory == true {
            return .directory(
                url: url,
                contents: .unloaded
            )
        }

        guard
            values.isRegularFile == true,
            url.pathExtension.caseInsensitiveCompare("pdf")
                == .orderedSame
        else {
            return nil
        }

        return .pdf(url: url)
    }

    nonisolated private static func sortsBefore(
        _ first: PDFTreeNode,
        _ second: PDFTreeNode
    ) -> Bool {
        switch (first, second) {
        case (.directory, .pdf):
            true
        case (.pdf, .directory):
            false
        default:
            first.displayName.localizedStandardCompare(
                second.displayName
            ) == .orderedAscending
        }
    }
}
