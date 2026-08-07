# PDF Navigator Architecture

This document translates `product-requirements.md` into the current technical
ownership model. Product terminology comes from the requirements; type names
describe implementation scope. This is the project's present landing point,
not a promise that every current type or boundary is permanent.

## Direction

PDF Navigator uses an AppKit-first macOS shell:

- AppKit owns application and document opening, native windows and tabs, the
  native toolbar, menus, split-view geometry, and command routing.
- SwiftUI is the default for populated presentation surfaces such as the launch
  panel, workspace home, cards, and small sidebar accessories.
- AppKit remains appropriate where the native component is the feature: the
  navigator uses `NSOutlineView`, and the reader uses PDFKit's `PDFView`.
- PDFKit owns PDF rendering and PDF operations inside the AppKit reader
  controller.

AppKit is the host and SwiftUI is the guest. The workspace does not use a
parallel SwiftUI `WindowGroup`, a window-introspection bridge, or SwiftUI
toolbar publication. "AppKit-first shell" does not mean "AppKit-first
content": new content regions should start in SwiftUI unless a concrete native
behavior requires AppKit.

## Source Structure

```text
PDFNavigator/
  AppDelegate.swift
  DevelopmentConfiguration.swift
  MainMenu.swift
  OpenRequest.swift
  WorkspaceDocument.swift

  Components/
    FileCardView.swift
    FolderCardView.swift
    HoverButtonStyle.swift
    RecentRowView.swift

  Window/
    WindowController.swift
    WindowRouting.swift
    WindowToolbar.swift
    WorkspaceActions.swift
    WorkspaceSplitController.swift
    TabSession.swift
    NavigationHistory.swift

  LaunchPanel/
    LaunchPanelController.swift
    LaunchPanelHeaderView.swift
    LaunchPanelView.swift
    RecentPDFsSectionView.swift
    RecentWorkspacesSectionView.swift

  Workspace/
    FileCardGridView.swift
    WorkspaceHeaderView.swift
    WorkspaceHomeContentView.swift
    WorkspaceHomeView.swift

  Navigator/
    SidebarController.swift
    NavigatorController.swift
    NavigatorItem.swift
    DirectoryScanner.swift
    SidebarHeaderView.swift
    SidebarFooterView.swift

  Reader/
    PDFSession.swift
    PDFReaderController.swift
    PDFReaderPresentationState.swift
    PDFReaderPreview.swift
    ReadingPositionStore.swift

    Inspector/
      PDFInspectorView.swift
      PDFThumbnailsView.swift
      PDFOutlineView.swift
      PDFInfoView.swift

  Stores/
    RecentLocationsStore.swift
```

The source root contains application entry, lifecycle, and top-level routing.
Directories group concrete features or responsibilities. App-wide persistence
lives in `Stores`; feature-private persistence stays with its feature.
`PreviewHost/` is a separate, currently unused stock preview target and is not
part of the production architecture.

`PDFNavigator.xcodeproj` is the authoritative project used by
`script/build_and_run.sh` and the shared schemes. `PDFNavigator 2.xcodeproj` is
a stale duplicate whose own schemes still reference `PDFNavigator.xcodeproj`;
do not use it as architectural or build configuration authority.

## Runtime Model

A **workspace** is a directory used as the navigation root. It is not a window,
tab, controller, or globally unique runtime object.

A `TabSession` is the mutable browsing state of one native tab or standalone
window:

```text
TabSession
  root: URL
  selection: URL?
  pdfSession: PDFSession?
  navigation history
```

Multiple `TabSession` instances may reference the same workspace root. Their
selection, search, PDF state, and history remain independent. Shared directory
data should be introduced only if measured duplication justifies it; UI
controllers and mutable navigation state must not be shared between tabs.

A `PDFSession` is the source of truth for one open PDF:

```text
PDFSession
  URL and PDFDocument
  search query and matches
  selected search match
  reading position
```

There is no global current workspace or current PDF.

## Ownership

```text
AppDelegate
  retains MainMenu, owns open routing and native tab attachment
  installs per-window WindowRouting callbacks

LaunchPanelController
  owns the no-workspace AppKit window
  hosts LaunchPanelView as its SwiftUI content

WorkspaceDocument
  retains the NSDocument-to-window-controller lifecycle relationship

WindowController
  owns one NSWindow, including a window presented as a native tab
  owns one TabSession, WindowToolbar, and WorkspaceSplitController

WorkspaceSplitController
  owns the AppKit navigator/detail/inspector composition
  hosts WorkspaceHomeContentView for workspace-home presentation
  installs PDFReaderController directly for reading
  hosts PDFInspectorView inside the native inspector split item

SidebarController
  owns the native navigator and hosts the SwiftUI footer accessory
```

Each native tab has its own `NSWindow` and `NSWindowController`, so each tab
also has its own toolbar, split controller, sidebar controller, and reader
controller. Native tab grouping controls presentation; it does not create a
shared controller tree.

`TabSession` and `PDFSession` remain the authoritative state owners. Rendering
controllers may retain the last values they were given when AppKit needs them
for diffing or selection (`NavigatorController` does this for its root and
selected URL), but those copies are presentation inputs rather than a second
mutable source of truth. Navigation and search state change only through the
session APIs.

## AppKit-SwiftUI Contract

The framework boundary uses only Apple-supported interoperability types:

1. AppKit embeds a controller-sized SwiftUI region with
   [`NSHostingController`](https://developer.apple.com/documentation/swiftui/nshostingcontroller).
2. AppKit embeds a small SwiftUI accessory with
   [`NSHostingView`](https://developer.apple.com/documentation/swiftui/nshostingview).
3. A SwiftUI preview may wrap a production AppKit controller with
   [`NSViewControllerRepresentable`](https://developer.apple.com/documentation/swiftui/nsviewcontrollerrepresentable).
   Production composition installs the AppKit controller directly.
4. Observable state crosses as `TabSession`, `PDFSession`, or the narrow
   `PDFReaderPresentationState`; none exposes a framework view.
5. Intent returns to the shell through `WorkspaceActions`, an immutable,
   framework-neutral closure value.

`WorkspaceActions` is the complete workspace-content-to-shell API:

```swift
struct WorkspaceActions {
    let chooseLocation: () -> Void
    let openInNewTab: (URL, TabActivation) -> Void
    let revealInFinder: (URL) -> Void
    let beginSearch: () -> Void
}
```

SwiftUI content must not receive an `NSWindow`, `NSView`, `NSViewController`,
`NSResponder`, or toolbar object. AppKit constructs hosted roots with explicit
state and actions. Hosted child views receive only the individual values and
closures they use. `URL`, PDFKit data objects, and the small `TabActivation`
value may cross this boundary; AppKit and SwiftUI view objects may not.

`WindowRouting` is not part of the SwiftUI contract. It is an AppKit-only,
per-window installation point used because `WorkspaceDocument` creates the
window controller before `AppDelegate` can bind source-window-specific open and
tab operations.

The workspace shell must not use:

- SwiftUI `WindowGroup` alongside AppKit workspace windows.
- `NSHostingController.sceneBridgingOptions = [.toolbars]`.
- A `WindowBridge` that resolves an AppKit window after SwiftUI creates it.
- `NSViewRepresentable` or `NSViewControllerRepresentable` as a production
  wrapper when AppKit can install the controller directly.

## Opening

`OpenRequest` is the single normalized input for opening a folder or PDF:

```swift
struct OpenRequest {
    let workspaceRootURL: URL
    let selectedPDFURL: URL?
}
```

- A folder request uses that folder as the workspace root.
- A PDF request uses the PDF parent directory as the workspace root and selects
  the PDF.
- The `folder(_:)`, `pdf(_:)`, and `pdf(_:in:)` factories standardize URLs and
  preserve an existing workspace root when a PDF opens in a new tab.

`AppDelegate` resolves Finder, menu, recent-item, new-window, and new-tab opens.
`Cmd-N` presents the location picker and creates an independent window only
after a selection. `Cmd-T` creates a native tab and inherits the current root
without inheriting the selected PDF.

AppKit creates each destination `NSWindow` before calling
`addTabbedWindow(_:ordered:)`; it never reparents a SwiftUI-scene window after
the fact.

## `WorkspaceDocument`

`WorkspaceDocument` is a temporary read-only `NSDocument` lifecycle adapter.
It stores the normalized workspace-root and selected-PDF URLs needed to create
a `WindowController`, and lets `NSDocumentController` retain the relationship.
It does not own live workspace, PDF, search, or navigation state and does not
support editing or saving.

Removing it requires a separate window-lifetime refactor and verification of
Finder opening, independent windows, native tabs, tab detachment, and closing.
It should not acquire additional responsibilities in the meantime.

## Window Shell and Commands

`WindowController` creates and configures the `NSWindow`, routes responder-chain
commands, validates menu and toolbar items, and projects `TabSession` changes
into the title, represented URL, recents, toolbar state, and visible content.

`WindowToolbar` owns `NSToolbarDelegate`, toolbar item creation, search
presentation, and enabled state. Toolbar customization autosaving is enabled in
Release and intentionally disabled in DEBUG. Persisted toolbar and split-view
identifiers are compatibility keys and do not need to match current type names.

Menus and toolbar items target the same small `@objc` methods on
`WindowController`. Back/forward navigation among workspace homes and selected
PDFs belongs to `TabSession`; page navigation inside the current PDF belongs to
`PDFReaderController` and PDFKit.

## Navigator

`NavigatorController` owns the native source-list outline, lazy loading,
selection, expansion, command-click handling, keyboard navigation, and sidebar
actions. `DirectoryScanner` owns filesystem enumeration. `NavigatorItem` is the
sendable value returned by the scanner.

Directory scanning remains lazy. Do not recursively enumerate an arbitrary
workspace on open. `SidebarController` currently hosts
`SidebarFooterView` below the native outline. `SidebarHeaderView` still exists
in source but is temporarily disconnected; it must not be described as current
UI. AppKit continues to own sidebar material, scrolling, selection, and
responder behavior.

## Reader and Search

`PDFReaderController` owns the `PDFView` and rendered selections. `PDFSession`
owns the document, search operation, matches, current match, and reading
position. Global commands call controller or session capabilities rather than
reaching into a raw `PDFView`.

`PDFReaderPreview` is a DEBUG-only `NSViewControllerRepresentable` adapter for
the canvas. It is not part of production composition.

`WorkspaceSplitController` owns the native inspector split item and hosts
`PDFInspectorView` there. The inspector is SwiftUI because PDFKit supplies its
document data but the app owns this presentation. Its three sections consume
the current `PDFDocument` directly:

- `PDFThumbnailsView` renders page thumbnails and returns page-selection intent.
- `PDFOutlineView` renders the PDF outline and returns outline-selection intent.
- `PDFInfoView` presents document metadata and current reader status.

`WorkspaceSplitController` reports the inspector's visibility and active
section to `WindowToolbar`. The native reader-panel group uses those values to
select exactly one matching segment, or no segment while the inspector is
collapsed.

The private `PDFView` never crosses into SwiftUI. `PDFReaderController` performs
page and outline navigation, observes PDFKit page/scale notifications, and
publishes only `PDFReaderPresentationState` for current-page highlighting and
reader status. Trackpad magnification belongs to PDFKit's nested scroll view,
so the controller observes its magnification-start notification and leaves
`autoScales` before publishing the new zoom mode. This projection is
presentation state, not a second owner of the document or reading position.

On macOS 26 and later, the detail split item allows native sidebars and
inspectors to overlay it and adjusts its safe area. Workspace-home content uses
that safe area, while `PDFReaderController` is intentionally constrained to the
full detail bounds so the native materials can sample PDF content underneath.
Do not replace that geometry with custom blur or opacity layers.

## Persistence

Persist concepts with their owner:

- Recent workspaces and PDFs: `RecentLocationsStore`.
- Window and tab restoration: native AppKit `NSDocument` / `NSWindow` state restoration.
- Reading positions: `ReadingPositionStore`.
- Toolbar customization: native `NSToolbar` autosaving.
- Sidebar width: native split-view autosaving.

Restored file access will require security-scoped bookmarks before sandboxed
distribution. Raw URLs are acceptable for current runtime state but are not a
complete sandbox restoration design.

## Naming Rules

- `Window` names refer to native window-shell ownership.
- `Workspace` names refer to one tab's directory-backed browsing context.
- `Reader` names refer to PDFKit-backed reading behavior.
- `ContentView` names are SwiftUI regions hosted by an AppKit controller.
- `Controller` names are AppKit controller objects with lifecycle ownership.
- `Routing` names are AppKit-only callback installation points.
- `Actions` names are immutable UI intent contracts with no framework objects.
- File names match their primary type.

## Non-Goals

- A globally unique workspace instance for every root URL.
- Shared mutable tab sessions or UI controllers.
- A custom tab strip or parallel SwiftUI window system.
- A protocol, coordinator, or service for a single concrete implementation.
- Splitting cohesive controllers solely to reduce line counts.
- Treating one PDF as the entire application model.
