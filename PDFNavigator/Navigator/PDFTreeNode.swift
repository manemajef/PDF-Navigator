//
//  PDFTreeNode.swift
//  PDFNavigator
//
//  Created by Rotem Semah on 27/07/2026.
//
import Foundation

indirect enum PDFTreeNode: Identifiable, Hashable {
    case directory(
        url: URL,
        children: [PDFTreeNode]
    )
    case pdf(url: URL)

    var id: URL {
        url
    }

    var url: URL {
        switch self {
        case .directory(let url, _):
            return url

        case .pdf(let url):
            return url
        }
    }

    var children: [PDFTreeNode]? {
        switch self {
        case .directory(_, let children):
            return children

        case .pdf:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .directory(let url, _):
            return url.lastPathComponent

        case .pdf(let url):
            return url.lastPathComponent
        }
    }
}
