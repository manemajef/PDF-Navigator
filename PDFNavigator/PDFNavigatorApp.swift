//
//  PDF_NavigatorApp.swift
//  PDF Navigator
//
//  Created by Rotem Semah on 27/07/2026.
//

import SwiftUI

@main
struct PDFNavigatorApp: App {
    var body: some Scene {
        WindowGroup(for: WorkspaceLaunch.self) { $launch in
            WorkspaceView(
                restoration: $launch,
                initialPDF: initialPDF(for: launch),
                initialWorkspace: launch?.rootURL,
                lastSelectedPDF: launch?.lastSelectedPDF,
                launchID: launch?.id,
                presentsPicker: launch?.presentsPicker == true,
                startsAtWelcome: launch?.startsAtWelcome == true
            )
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 700, height: 850)
        .commands {
            WorkspaceCommands()
        }

        Settings {
            ContentUnavailableView("No Settings", systemImage: "gear")
                .frame(width: 360, height: 180)
        }
    }

    private func initialPDF(
        for launch: WorkspaceLaunch?
    ) -> URL? {
        if let selectedPDF = launch?.selectedPDF {
            return selectedPDF
        }

        #if DEBUG
        return launch == nil
            ? DevelopmentConfiguration.demoPDFURL
            : nil
        #else
        return nil
        #endif
    }
}

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
}
#endif
