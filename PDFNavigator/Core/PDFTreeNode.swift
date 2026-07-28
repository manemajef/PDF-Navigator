import Foundation

indirect enum PDFTreeNode: Identifiable, Hashable, Sendable {
    case directory(
        url: URL,
        contents: DirectoryContents
    )
    case pdf(url: URL)

    enum DirectoryContents: Hashable, Sendable {
        case unloaded
        case loading
        case loaded([PDFTreeNode])
        case unavailable
    }

    nonisolated var id: URL {
        url
    }

    nonisolated var url: URL {
        switch self {
        case .directory(let url, _), .pdf(let url):
            url
        }
    }

    nonisolated var displayName: String {
        url.lastPathComponent
    }

    nonisolated var isPDF: Bool {
        if case .pdf = self {
            true
        } else {
            false
        }
    }
}

extension Collection where Element == PDFTreeNode {
    nonisolated func node(
        matching url: URL
    ) -> PDFTreeNode? {
        for node in self {
            if node.url == url {
                return node
            }

            if case .directory(
                _,
                .loaded(let children)
            ) = node,
               let match = children.node(matching: url) {
                return match
            }
        }

        return nil
    }

    nonisolated func directoryContents(
        at url: URL
    ) -> PDFTreeNode.DirectoryContents? {
        guard let node = node(matching: url) else {
            return nil
        }

        guard case .directory(_, let contents) = node else {
            return nil
        }

        return contents
    }

    nonisolated func directoryAncestors(
        containing selectedPDF: URL
    ) -> Set<URL> {
        for node in self {
            switch node {
            case .pdf(let url):
                if url == selectedPDF {
                    return []
                }
            case .directory(
                let url,
                .loaded(let children)
            ):
                if children.node(
                    matching: selectedPDF
                ) != nil {
                    return Set([url]).union(
                        children.directoryAncestors(
                            containing: selectedPDF
                        )
                    )
                }
            case .directory:
                continue
            }
        }

        return []
    }

    nonisolated var firstPDF: URL? {
        lazy.compactMap { node in
            if case .pdf(let url) = node {
                url
            } else {
                nil
            }
        }
        .first
    }
}

extension Array where Element == PDFTreeNode {
    nonisolated func replacingDirectoryContents(
        at directory: URL,
        with contents: PDFTreeNode.DirectoryContents
    ) -> [PDFTreeNode] {
        map { node in
            guard case .directory(
                let url,
                let currentContents
            ) = node else {
                return node
            }

            if url == directory {
                return .directory(
                    url: url,
                    contents: contents
                )
            }

            guard case .loaded(let children) =
                currentContents
            else {
                return node
            }

            return .directory(
                url: url,
                contents: .loaded(
                    children.replacingDirectoryContents(
                        at: directory,
                        with: contents
                    )
                )
            )
        }
    }
}
