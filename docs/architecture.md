# PDF Navigator Architecture

This document translates `product-requirements.md` into current technical
ownership rules. Product terminology comes from the requirements; type names
describe implementation scope.

## Direction

PDF Navigator uses an AppKit-first macOS shell. AppKit owns application and
window lifecycle, native tabs, the toolbar, the sidebar split, menus, and
command routing. PDFKit owns PDF rendering and operations. SwiftUI is used only
inside contained views where it reduces presentation code.

## Source Structure

```text
PDFNavigator/
  AppDelegate.swift
  MainMenu.swift
  OpenRequest.swift
  WorkspaceDocument.swift

  Window/
    WindowController.swift
    WindowContentController.swift
    WindowToolbar.swift
    WindowActions.swift
    TabSession.swift
    NavigationHistory.swift

  LaunchPanel/
    LaunchPanelController.swift
    LaunchPanelView.swift

  Workspace/
    WorkspaceHomeController.swift
    WorkspaceHomeView.swift

  Sidebar/
    SidebarView.swift
    SidebarItemRowView.swift
    NavigatorItem.swift
    DirectoryScanner.swift

  Reader/
    PDFSession.swift
    PDFReaderController.swift
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
  creates WindowController instances
  configures app-level WindowActions
  owns menus and open routing

WindowController
  owns one NSWindow, including a window used as a native tab
  owns one TabSession
  owns one WindowToolbar
  owns one WindowContentController

WindowContentController
  owns the SwiftUI sidebar hosting controller
  owns PDFReaderController
  owns WorkspaceHomeController
  switches the detail content from TabSession.mode
```

Each native tab has its own `NSWindow` and `NSWindowController`, so each tab
also has its own toolbar, split-view controller, sidebar controller, and reader
controller. Native tab grouping controls presentation; it does not create a
shared controller tree.

Controllers read state from `TabSession` and mutate it through session methods.
They must not cache their own copies of the workspace root, selected PDF, search
state, or navigation history.

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
Child controllers receive only the four app-level operations in
`WindowActions`: choose a location, open a PDF in the current tab, open a PDF in
a new tab, and create a new tab.

`Cmd-N` presents the location picker and creates an independent window only
after a selection. `Cmd-T` creates a native tab and inherits the current root
without inheriting the selected PDF. Opening a PDF in a new tab creates another
independent `TabSession` in the same native tab group. The launch panel is the
only no-workspace UI.

## `WorkspaceDocument`

`WorkspaceDocument` is a temporary read-only `NSDocument` lifecycle adapter.
It stores the initial `OpenRequest`, creates a `WindowController`, and lets
`NSDocumentController` retain the relationship. It does not own live workspace,
PDF, search, or navigation state and it does not support editing or saving.

Removing it requires a separate window-lifetime refactor and verification of
Finder opening, independent windows, native tabs, tab detachment, and closing.
It should not acquire additional responsibilities in the meantime.

## Window Shell

`WindowController` creates and configures the `NSWindow`, routes responder-chain
commands, validates menu items, and projects `TabSession` changes into the
window title, represented URL, recents, toolbar state, and visible content.

`WindowContentController` owns the stable sidebar/detail composition:

- `.workspaceHome`: no selected PDF; show
  `WorkspaceHomeController`.
- `.reading`: install `PDFReaderController` and display the current
  `PDFSession`.

`WindowToolbar` owns `NSToolbarDelegate`, toolbar item creation, search-field
delegation, and back/forward enabled state. Persisted toolbar and split-view
identifiers are compatibility keys and do not need to match current type names.

## Navigator

`WindowContentController` hosts `SidebarView` as the native split sidebar.
`SidebarViewModel` owns its presentation tree, lazy loading, selection, and
expansion state. `DirectoryScanner` owns filesystem enumeration. `NavigatorItem`
is the sendable value returned by the scanner.

Directory scanning remains lazy. Do not recursively enumerate an arbitrary
workspace on open. The production sidebar and its `#Preview` use the same
`SidebarView`; previews replace only URLs and action closures with sample data.

## Reader and Search

`PDFReaderController` owns the `PDFView` and rendered selections. `PDFSession`
owns the document, search operation, matches, current match, and reading
position. Global commands call controller or session capabilities rather than
reaching into a raw `PDFView`.

Changing the selected PDF creates a new `PDFSession`. Search cancellation and
observer cleanup belong to the old session, while the reader only updates its
rendered state.

## Commands

Menus and toolbar items use the AppKit responder chain and target the same
small `@objc` methods on `WindowController`. `WindowActions` exists only for
app-level operations that child controllers cannot perform themselves. It must
not expose state or framework views.

PDF-to-PDF back/forward navigation is owned by `TabSession`. Page navigation
inside the current PDF is owned by `PDFReaderController` and PDFKit. These are
separate commands.

## Persistence

Persist concepts with their owner:

- Recent workspaces and PDFs: `RecentLocationsStore`.
- Reading positions: `ReadingPositionStore`.
- Toolbar customization: native `NSToolbar` autosaving.
- Sidebar width: native split-view autosaving.

Restored file access will require security-scoped bookmarks before sandboxed
distribution. Raw URLs are acceptable for current runtime state but are not a
complete sandbox restoration design.

## Non-Goals

- A globally unique workspace instance for every root URL.
- Shared mutable tab sessions or UI controllers.
- A custom tab strip or parallel SwiftUI window system.
- A protocol, coordinator, or service for a single concrete implementation.
- Splitting cohesive controllers solely to reduce line counts.
- Treating one PDF as the entire application model.
