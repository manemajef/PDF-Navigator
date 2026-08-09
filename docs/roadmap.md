# Roadmap

## Principles

- AppKit owns application and document opening, native windows and tabs, the
  toolbar, menus, split geometry, native navigator, and PDFKit integration.
- The responder chain owns menu and toolbar commands. `ShellActions` is the
  narrow content-to-shell intent boundary, not a parallel command system.
- SwiftUI stays inside AppKit-hosted presentation regions and is the default
  for new populated content. AppKit is used where native behavior is the point,
  notably `NSOutlineView` navigation and PDFKit's `PDFView`.
- Workspace means a directory. `WorkspaceSession` owns one tab's navigation state.
- Refactor around real ownership boundaries, not file length alone.
- Prefer deletion and native framework behavior over compatibility wrappers.
- Treat this as the current direction while the structure is still evolving;
  do not turn it into speculative layers or permanent abstractions.

## Architecture Follow-Up

- [ ] Replace the temporary `WorkspaceDocument` lifecycle adapter only after
  Finder opening, window retention, native tabs, tab detachment, and closing can
  be verified together.
- [ ] Remove the unused stock `PreviewHost` target, or make it serve a real
  preview workflow.
- [ ] Remove the stale `PDFNavigator 2.xcodeproj` duplicate after confirming no
  local workflow still opens it; `PDFNavigator.xcodeproj` is authoritative.
- [ ] Populate and reconnect `SidebarHeaderView` with the intended navigator
  controls.
- [ ] Consolidate the competing app-icon sources after confirming which design
  is intended and which source the application currently builds.
- [ ] Add sandbox-safe folder authorization and restoration when distribution
  work begins.

## Correctness and Presentation

- [ ] Verify toolbar and sidebar behavior across independent windows, grouped
  tabs, and detached tabs.
- [ ] Verify window sizing on small and large displays.
- [ ] Refine the launch-panel and library presentation.
- [ ] Improve light and dark window/sidebar contrast.
- [ ] Refine title-bar typography and spacing.

## Features

- [ ] Sidebar action bar for parent navigation and folder search.
- [ ] Workspace restoration, including expanded directories where practical.
- [ ] Refine inspector thumbnail loading, outline interaction, and metadata
  presentation against large and unusual PDFs.

## Completed Foundations

- [x] AppKit window, native-tab, toolbar, sidebar split, menu, and PDFKit shell.
- [x] Separate launch-panel and workspace-home surfaces.
- [x] Separate recent workspaces and recent PDFs, capped at 20 in the shared
  recents store and exposed in the launch panel and Open Recent menu.
- [x] Show workspace-filtered recent PDFs as SwiftUI Quick Look thumbnail cards
  on the workspace home surface.
- [x] `WorkspaceSession` owns root, selection, PDF session, and navigation history.
- [x] `PDFSession` owns document, search, matches, and reading position.
- [x] Native Combine publishers replace custom change notification code.
- [x] Main menu and toolbar have focused owners.
- [x] Navigator controller, scanning, and item data have substantive boundaries.
- [x] AppKit hosts SwiftUI through `NSHostingController`/`NSHostingView`; the
  framework-neutral `ShellActions` contract carries content intent.
- [x] Reader commands are available as optional native toolbar items.
- [x] PDFs in the navigator and the workspace root can be revealed in Finder.
- [x] Production SwiftUI reader inspector is hosted by the native AppKit split
  item, with PDFKit page/outline actions returning to `PDFReaderController`.

## Decided Against for Now

- A global workspace registry keyed by root URL.
- Shared controllers or mutable session state between tabs with the same root.
- Splitting `NavigatorController` into forwarding controller/view wrappers.
- A custom command layer on top of the AppKit responder chain.
- Replacing the native AppKit split or native tabs with custom SwiftUI versions.
