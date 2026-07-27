//
//  DevelopmentConfiguration.swift
//  PDFNavigator
//
//  Created by Rotem Semah on 27/07/2026.
//

import Foundation

#if DEBUG
enum DevelopmentConfiguration {
    static let demoPDFURL = repositoryRoot
        .appendingPathComponent("DEMO_DIR", isDirectory: true)
        .appendingPathComponent("micro3-sylabus.pdf", isDirectory: false)
    private static let repositoryRoot = URL(
        fileURLWithPath: #filePath
    )
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}
#endif

