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
        WindowGroup(
            for: WorkspaceLaunchContext.self
        ) { $configuration in
            WorkspaceSplitView(
                initialPDF: initialPDF(for: configuration),
                initialWorkspace:
                    configuration?.workspaceURL,
                lastSelectedPDF:
                    configuration?.lastSelectedPDF,
                launchContextID:
                    configuration?.id,
                presentsWorkspacePicker:
                    configuration?
                        .presentsWorkspacePicker == true,
                startsAtWelcome:
                    configuration?.startsAtWelcome == true
            )
        }
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            WorkspaceCommands()
            ToolbarCommands()
        }
    }

    private func initialPDF(
        for configuration: WorkspaceLaunchContext?
    ) -> URL? {
        if let selectedPDF = configuration?.selectedPDF {
            return selectedPDF
        }

        #if DEBUG
        return configuration == nil
            ? DevelopmentConfiguration.demoPDFURL
            : nil
        #else
        return nil
        #endif
    }
}

#if DEBUG
private enum DevelopmentConfiguration {
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
