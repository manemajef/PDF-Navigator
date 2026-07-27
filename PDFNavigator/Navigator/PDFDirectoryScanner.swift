//
//  PDFDirectoryScanner.swift
//  PDFNavigator
//
//  Created by Rotem Semah on 27/07/2026.
//

import Foundation

struct PDFDirectoryScanner {
    func scan(directory: URL) throws -> [PDFTreeNode] {
        let contents = try FileManager.default.contentsOfDirectory(
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
        return contents
            .compactMap(makeNode)
            .sorted(by: sortsBefore)
    }

    private func makeNode(for url: URL) -> PDFTreeNode? {
        guard let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]) else {
            return nil
        }
        guard values.isSymbolicLink != true else {
            return nil
        }

        if values.isDirectory == true {
            guard
                let children = try? scan(directory: url),
                !children.isEmpty
            else {
                return nil
            }
            return .directory(
                url: url,
                children: children
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

    private func sortsBefore(
        _ first: PDFTreeNode,
        _ second: PDFTreeNode
    ) -> Bool {
        switch (first, second) {
        case (.directory(_,_), .pdf(_)):
            return true
        case (.pdf(_), .directory(_, _)):
            return false
        default:
            return first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }
    }

}
