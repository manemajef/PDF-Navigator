# Roadmap

## Principles

- AppKit owns application and document opening, native windows and tabs, the
  toolbar, menus, sidebar split, native navigator, and PDFKit integration.
- The responder chain owns menu and toolbar commands. `WorkspaceActions` is the
  narrow content-to-shell intent boundary, not a parallel command system.
- SwiftUI stays inside AppKit-hosted presentation regions.
- Workspace means a directory. `TabSession` owns one tab's navigation state.
- Refactor around real ownership boundaries, not file length alone.
- Prefer deletion and native framework behavior over compatibility wrappers.

## Architecture Follow-Up

- [ ] Replace the temporary `WorkspaceDocument` lifecycle adapter only after
  Finder opening, window retention, native tabs, tab detachment, and closing can
  be verified together.
- [ ] Remove the unused `PreviewHost` target and disconnected welcome mockup, or
  make the target serve a real preview workflow.
- [ ] Consolidate the competing app-icon sources after confirming which design
  is intended and which source the application currently builds.
- [ ] Add sandbox-safe folder authorization and restoration when distribution
  work begins.

## Correctness and Presentation

- [ ] Verify toolbar and sidebar behavior across independent windows, grouped
  tabs, and detached tabs.
- [ ] Verify window sizing on small and large displays.
- [ ] Refine the welcome and workspace-home presentation.
- [ ] Improve light and dark window/sidebar contrast.
- [ ] Refine title-bar typography and spacing.

## Features

- [ ] Sidebar action bar for parent navigation and folder search.
- [ ] Workspace restoration, including expanded directories where practical.

## Completed Foundations

- [x] AppKit window, native-tab, toolbar, sidebar split, menu, and PDFKit shell.
- [x] Separate launch-panel and workspace-home surfaces.
- [x] Separate recent workspaces and recent PDFs, capped at 20 in the shared
  recents store and exposed in the launch panel and Open Recent menu.
- [x] `TabSession` owns root, selection, PDF session, and navigation history.
- [x] `PDFSession` owns document, search, matches, and reading position.
- [x] Native Combine publishers replace custom change notification code.
- [x] Main menu and toolbar have focused owners.
- [x] Navigator controller, scanning, and item data have substantive boundaries.
- [x] AppKit hosts SwiftUI through `NSHostingController`/`NSHostingView`; the
  framework-neutral `WorkspaceActions` contract carries content intent.
- [x] Reader commands are available as optional native toolbar items.
- [x] Navigator files and the workspace root can be revealed in Finder.

## Decided Against for Now

- A global workspace registry keyed by root URL.
- Shared controllers or mutable session state between tabs with the same root.
- Splitting `NavigatorController` into forwarding controller/view wrappers.
- A custom command layer on top of the AppKit responder chain.
- Replacing the native AppKit split or native tabs with custom SwiftUI versions.
