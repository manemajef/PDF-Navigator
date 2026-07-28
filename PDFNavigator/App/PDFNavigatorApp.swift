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
            for: WorkspaceWindowConfiguration.self
        ) { $configuration in
            WorkspaceView(
                initialPDF: initialPDF(for: configuration),
                initialWorkspace:
                    configuration?.workspaceURL,
                lastSelectedPDF:
                    configuration?.lastSelectedPDF,
                sourceWindowNumber:
                    configuration?.sourceWindowNumber,
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
        for configuration: WorkspaceWindowConfiguration?
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
