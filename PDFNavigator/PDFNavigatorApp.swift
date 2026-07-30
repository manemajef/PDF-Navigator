//
//  PDF_NavigatorApp.swift
//  PDF Navigator
//
//  Created by Rotem Semah on 27/07/2026.
//

import SwiftUI

@main
struct PDFNavigatorApp: App {
    @NSApplicationDelegateAdaptor(AppKitWindowShell.self)
    private var appKitWindowShell

    var body: some Scene {
        WindowGroup(for: WorkspaceLaunch.self) { $launch in
            WorkspaceView(
                restoration: $launch,
                initialPDF: launch?.selectedPDF,
                initialWorkspace: launch?.rootURL,
                lastSelectedPDF: launch?.lastSelectedPDF,
                launchID: launch?.id,
                presentsPicker: launch?.presentsPicker == true,
                startsAtWelcome: launch?.startsAtWelcome ?? true
            )
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 700, height: 850)
        .defaultLaunchBehavior(WindowShellSelection.current.launchBehavior)
        .restorationBehavior(
            WindowShellSelection.current == .appKitExperiment
                ? .disabled
                : .automatic
        )
        .commands {
            WorkspaceCommands(
                openWorkspaceWithAppKit: appKitWindowShell.workspaceOpener
            )
        }

        Settings {
            ContentUnavailableView("No Settings", systemImage: "gear")
                .frame(width: 360, height: 180)
        }
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
