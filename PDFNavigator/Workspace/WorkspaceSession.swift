//
//  PDF Library.swift
//  PDF Navigator
//
//  Created by Rotem Semah on 27/07/2026.

import Foundation
import Combine

@MainActor
final class WorkspaceSession: ObservableObject {
    @Published private(set) var navigatorNodes: [PDFTreeNode] = []
    @Published private(set) var selectedPDF: URL?

    @Published var errorMessage = ""
    @Published var showingError = false

    private var folderURL: URL?
    private var isUsingSecurityScopedAccess = false
    private let directoryScanner = PDFDirectoryScanner()
    private var navigationHistory = NavigationHistory()

    init(
        initialPDF: URL? = nil,
        initialWorkspace: URL? = nil
    ) {
        if let initialWorkspace {
            open(folder: initialWorkspace)

            if let initialPDF {
                setInitialSelection(to: initialPDF)
            }
        } else if let initialPDF {
            open(pdf: initialPDF)
        }
    }

    var canGoBack: Bool {
        navigationHistory.canGoBack
    }

    var canGoForward: Bool {
        navigationHistory.canGoForward
    }

    var workspaceURL: URL? {
        folderURL
    }

    var folderName: String {
        folderURL?.lastPathComponent ?? "PDF's"
    }

    func select(pdf: URL) {
        guard contains(pdf: pdf, in: navigatorNodes) else {
            return
        }

        navigationHistory.visit(pdf)
        selectedPDF = pdf
    }

    func goBack() {
        guard let pdf = navigationHistory.goBack() else {
            return
        }

        selectedPDF = pdf
    }

    func goForward() {
        guard let pdf = navigationHistory.goForward() else {
            return
        }

        selectedPDF = pdf
    }

    func open(pdf: URL) {
        let workspace = pdf.deletingLastPathComponent()
        open(folder: workspace)
        setInitialSelection(to: pdf)
    }

    func open(folder: URL) {
        stopAccessingCurrentFolder()
        folderURL = folder

        isUsingSecurityScopedAccess =
            folder.startAccessingSecurityScopedResource()

        do {
            navigatorNodes = try directoryScanner.scan(
                directory: folder
            )

            selectedPDF = firstPDF(in: navigatorNodes)
            navigationHistory.reset(to: selectedPDF)
        } catch {
            navigatorNodes = []
            selectedPDF = nil
            navigationHistory.reset(to: nil)
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func setInitialSelection(to pdf: URL) {
        guard contains(pdf: pdf, in: navigatorNodes) else {
            return
        }

        selectedPDF = pdf
        navigationHistory.reset(to: pdf)
    }

    private func stopAccessingCurrentFolder() {
        if isUsingSecurityScopedAccess {
            folderURL?.stopAccessingSecurityScopedResource()
        }

        isUsingSecurityScopedAccess = false
        folderURL = nil
    }

    private func firstPDF(
        in nodes: [PDFTreeNode]
    ) -> URL? {
        for node in nodes {
            switch node {
            case .pdf(let url):
                return url

            case .directory(_, let children):
                if let url = firstPDF(in: children) {
                    return url
                }
            }
        }

        return nil
    }

    private func contains(
        pdf: URL,
        in nodes: [PDFTreeNode]
    ) -> Bool {
        nodes.contains { node in
            if node.url == pdf {
                return true
            }

            guard let children = node.children else {
                return false
            }

            return contains(pdf: pdf, in: children)
        }
    }
}
