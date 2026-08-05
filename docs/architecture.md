# PDF Navigator Architecture

This document translates `product-requirements.md` into current technical
ownership rules. Product terminology comes from the requirements; type names
describe implementation scope.

## Direction

PDF Navigator uses an AppKit-first macOS shell:

- AppKit owns application and document opening, native windows and tabs, the
  native toolbar, menus, the sidebar split, and command routing.
- PDFKit owns PDF rendering and PDF operations.
- SwiftUI owns contained presentation regions where declarative layout and
  previews are useful.

AppKit is the host and SwiftUI is the guest. The workspace does not use a
parallel SwiftUI `WindowGroup`, a window-introspection bridge, or SwiftUI
toolbar publication.

## Source Structure

```text
PDFNavigator/
  AppDelegate.swift
  MainMenu.swift
  OpenRequest.swift
  WorkspaceDocument.swift

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
    LaunchPanelView.swift

  Workspace/
    WorkspaceHomeContentView.swift
    WorkspaceHomeView.swift

  Sidebar/
    SidebarController.swift
    NavigatorController.swift
    NavigatorItem.swift
    DirectoryScanner.swift
    SidebarHeaderView.swift
    SidebarFooterView.swift

  Reader/
    PDFSession.swift
    PDFReaderController.swift
    PDFReaderPreview.swift
    ReadingPositionStore.swift

  Stores/
    RecentLocationsStore.swift
```

The source root contains application entry, lifecycle, and top-level routing.
Directories group concrete features or responsibilities. App-wide persistence
lives in `Stores`; feature-private persistence stays with its feature.

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
  owns menus, open routing, and native tab attachment
  installs per-window WindowRouting callbacks

WorkspaceDocument
  retains the NSDocument-to-window-controller lifecycle relationship

WindowController
  owns one NSWindow, including a window presented as a native tab
  owns one TabSession, WindowToolbar, and WorkspaceSplitController

WorkspaceSplitController
  owns the stable AppKit sidebar/detail composition
  hosts WorkspaceHomeContentView for workspace-home presentation
  installs PDFReaderController directly for reading

SidebarController
  owns the native navigator and hosts SwiftUI header/footer accessories
```

Each native tab has its own `NSWindow` and `NSWindowController`, so each tab
also has its own toolbar, split controller, sidebar controller, and reader
controller. Native tab grouping controls presentation; it does not create a
shared controller tree.

Controllers read state from `TabSession` and mutate it through session methods.
They must not cache copies of the workspace root, selected PDF, search state, or
navigation history.

## AppKit-SwiftUI Contract

The framework boundary uses only Apple-supported interoperability types:

1. AppKit embeds a controller-sized SwiftUI region with
   [`NSHostingController`](https://developer.apple.com/documentation/swiftui/nshostingcontroller).
2. AppKit embeds a small SwiftUI accessory with
   [`NSHostingView`](https://developer.apple.com/documentation/swiftui/nshostingview).
3. A SwiftUI preview may wrap a production AppKit controller with
   [`NSViewControllerRepresentable`](https://developer.apple.com/documentation/swiftui/nsviewcontrollerrepresentable).
   Production composition installs the AppKit controller directly.
4. Observable state crosses as `TabSession` or `PDFSession`; both expose domain
   state rather than framework views.
5. Intent returns to the shell through `WorkspaceActions`, an immutable closure
   value containing only Foundation types.

`WorkspaceActions` is the complete content-to-shell API:

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
closures they use.

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

`OpenRequest` is the single input for opening a folder or PDF:

```swift
enum OpenRequest {
    case folder(URL)
    case pdf(URL)
}
```

- A folder request uses that folder as the workspace root.
- A PDF request uses the PDF parent directory as the workspace root and selects
  the PDF.

`AppDelegate` resolves Finder, menu, recent-item, new-window, and new-tab opens.
`Cmd-N` presents the location picker and creates an independent window only
after a selection. `Cmd-T` creates a native tab and inherits the current root
without inheriting the selected PDF.

AppKit creates each destination `NSWindow` before calling
`addTabbedWindow(_:ordered:)`; it never reparents a SwiftUI-scene window after
the fact.

## `WorkspaceDocument`

`WorkspaceDocument` is a temporary read-only `NSDocument` lifecycle adapter.
It stores the initial `OpenRequest`, creates a `WindowController`, and lets
`NSDocumentController` retain the relationship. It does not own live workspace,
PDF, search, or navigation state and does not support editing or saving.

Removing it requires a separate window-lifetime refactor and verification of
Finder opening, independent windows, native tabs, tab detachment, and closing.
It should not acquire additional responsibilities in the meantime.

## Window Shell and Commands

`WindowController` creates and configures the `NSWindow`, routes responder-chain
commands, validates menu and toolbar items, and projects `TabSession` changes
into the title, represented URL, recents, toolbar state, and visible content.

`WindowToolbar` owns `NSToolbarDelegate`, toolbar item creation, search
presentation, and enabled state. Persisted toolbar and split-view identifiers
are compatibility keys and do not need to match current type names.

Menus and toolbar items target the same small `@objc` methods on
`WindowController`. PDF-to-PDF back/forward navigation belongs to `TabSession`;
page navigation inside the current PDF belongs to `PDFReaderController` and
PDFKit.

## Navigator

`NavigatorController` owns the native source-list outline, lazy loading,
selection, expansion, command-click handling, keyboard navigation, and sidebar
actions. `DirectoryScanner` owns filesystem enumeration. `NavigatorItem` is the
sendable value returned by the scanner.

Directory scanning remains lazy. Do not recursively enumerate an arbitrary
workspace on open. `SidebarController` hosts the SwiftUI `SidebarHeaderView`
and `SidebarFooterView` around the native outline. AppKit continues to own
sidebar material, scrolling, selection, and responder behavior.

## Reader and Search

`PDFReaderController` owns the `PDFView` and rendered selections. `PDFSession`
owns the document, search operation, matches, current match, and reading
position. Global commands call controller or session capabilities rather than
reaching into a raw `PDFView`.

`PDFReaderPreview` is a DEBUG-only `NSViewControllerRepresentable` adapter for
the canvas. It is not part of production composition.

## Persistence

Persist concepts with their owner:

- Recent workspaces and PDFs: `RecentLocationsStore`.
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
