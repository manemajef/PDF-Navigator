import Foundation

#if DEBUG
enum DevelopmentConfiguration {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let demoDirURL = repositoryRoot
        .appendingPathComponent("DEMO_DIR", isDirectory: true)

    static let demoPDFURL = demoDirURL
        .appendingPathComponent("micro3-sylabus.pdf", isDirectory: false)

    static let demoOutlinePDFURL = demoDirURL
        .appendingPathComponent("lecs/micro3-lec-8b.pdf", isDirectory: false)

    // MARK: - PDF Loading Helpers

    /// Loads PDF file URLs from a directory.
    ///
    /// - Parameters:
    ///   - directory: The root folder to scan. Defaults to `demoDirURL`.
    ///   - limit: Optional maximum number of PDF URLs to return.
    ///   - recursive: Whether to recursively scan child folders. Defaults to `true`.
    /// - Returns: An array of standardized PDF file URLs, sorted by path.
    static func loadPDFs(
        from directory: URL = demoDirURL,
        limit: Int? = nil,
        recursive: Bool = true
    ) -> [URL] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]

        var results: [URL] = []

        if !recursive {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            for url in urls {
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isSymbolicLink != true,
                      values.isRegularFile == true,
                      url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame else {
                    continue
                }
                results.append(url.standardizedFileURL)
            }
        } else {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isSymbolicLink != true,
                      values.isRegularFile == true,
                      url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame else {
                    continue
                }
                results.append(url.standardizedFileURL)
            }
        }

        results.sort {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }

        if let limit, limit > 0 {
            return Array(results.prefix(limit))
        }
        return results
    }

    /// Convenience overload to load PDFs from a relative subpath inside `demoDirURL` (e.g. `"lecs"`, `"hw"`, `"exams"`).
    static func loadPDFs(
        from subpath: String,
        limit: Int? = nil,
        recursive: Bool = true
    ) -> [URL] {
        loadPDFs(
            from: demoDirURL.appendingPathComponent(subpath, isDirectory: true),
            limit: limit,
            recursive: recursive
        )
    }

    /// Alias for `loadPDFs` to accommodate case variations.
    static func loadPDFS(
        from directory: URL = demoDirURL,
        limit: Int? = nil,
        recursive: Bool = true
    ) -> [URL] {
        loadPDFs(from: directory, limit: limit, recursive: recursive)
    }

    /// Alias for `loadPDFs` from subpath to accommodate case variations.
    static func loadPDFS(
        from subpath: String,
        limit: Int? = nil,
        recursive: Bool = true
    ) -> [URL] {
        loadPDFs(from: subpath, limit: limit, recursive: recursive)
    }

    // MARK: - Folder Loading Helpers

    /// Common demo folder URLs inside `DEMO_DIR`.
    static var demoFolderURLs: [URL] {
        loadFolders(from: demoDirURL)
    }

    /// Loads subdirectory URLs from a directory.
    ///
    /// - Parameters:
    ///   - directory: The root folder to scan. Defaults to `demoDirURL`.
    ///   - limit: Optional maximum number of folder URLs to return.
    ///   - recursive: Whether to recursively scan child folders. Defaults to `false`.
    /// - Returns: An array of standardized directory URLs, sorted by name.
    static func loadFolders(
        from directory: URL = demoDirURL,
        limit: Int? = nil,
        recursive: Bool = false
    ) -> [URL] {
        let items = DirectoryScanner.items(in: directory)
        var folders = items.filter(\.isDirectory).map(\.url)

        if recursive {
            for folder in folders {
                folders.append(contentsOf: loadFolders(from: folder, recursive: true))
            }
        }

        folders.sort {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        if let limit, limit > 0 {
            return Array(folders.prefix(limit))
        }
        return folders
    }

    // MARK: - Tree Loading Helpers

    /// Lightweight value-type node for previewing and testing folder and file hierarchies.
    struct TreeNode: Identifiable, Hashable, Sendable {
        var id: URL { url }
        let url: URL
        let isDirectory: Bool
        let children: [TreeNode]

        var name: String {
            url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        }
    }

    /// Returns a hierarchical `TreeNode` containing directories and PDFs from the specified directory.
    static func loadTree(
        from directory: URL = demoDirURL,
        maxDepth: Int? = nil
    ) -> TreeNode {
        loadTreeNode(
            for: directory.standardizedFileURL,
            isDirectory: true,
            currentDepth: 0,
            maxDepth: maxDepth
        )
    }

    /// Convenience overload to load a `TreeNode` hierarchy from a subpath inside `demoDirURL`.
    static func loadTree(
        from subpath: String,
        maxDepth: Int? = nil
    ) -> TreeNode {
        loadTree(
            from: demoDirURL.appendingPathComponent(subpath, isDirectory: true),
            maxDepth: maxDepth
        )
    }

    private static func loadTreeNode(
        for directory: URL,
        isDirectory: Bool,
        currentDepth: Int,
        maxDepth: Int?
    ) -> TreeNode {
        guard isDirectory else {
            return TreeNode(url: directory, isDirectory: false, children: [])
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return TreeNode(url: directory, isDirectory: true, children: [])
        }

        var dirURLs: [URL] = []
        var pdfURLs: [URL] = []

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true else {
                continue
            }

            if values.isDirectory == true {
                dirURLs.append(url.standardizedFileURL)
            } else if values.isRegularFile == true,
                      url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
                pdfURLs.append(url.standardizedFileURL)
            }
        }

        dirURLs.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        pdfURLs.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        let children: [TreeNode]
        if let maxDepth, currentDepth >= maxDepth {
            children = []
        } else {
            let dirNodes = dirURLs.map {
                loadTreeNode(for: $0, isDirectory: true, currentDepth: currentDepth + 1, maxDepth: maxDepth)
            }
            let pdfNodes = pdfURLs.map {
                TreeNode(url: $0, isDirectory: false, children: [])
            }
            children = dirNodes + pdfNodes
        }

        return TreeNode(url: directory, isDirectory: true, children: children)
    }

    // MARK: - Navigator Model Helpers

    /// Creates a native `FileTree` initialized with the given root.
    @MainActor
    static func tree(from root: URL = demoDirURL) -> FileTree {
        FileTree(root: root)
    }

    /// Default demo `FileTree` rooted at `demoDirURL`.
    @MainActor
    static var demoTree: FileTree {
        tree(from: demoDirURL)
    }

    /// Creates a `FileNode` root initialized with the given directory.
    static func rootNode(from root: URL = demoDirURL) -> FileNode {
        FileNode(url: root, isDirectory: true)
    }

    /// Default demo `FileNode` rooted at `demoDirURL`.
    static var demoRootNode: FileNode {
        rootNode(from: demoDirURL)
    }
}
#endif
