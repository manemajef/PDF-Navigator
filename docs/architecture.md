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
  panel, library, cards, and small sidebar accessories.
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
  WorkspaceDocument.swift

  Session/
    WorkspaceSession.swift
    WorkspaceMode.swift
    NavigationHistory.swift
    OpenRequest.swift

  Window/
    WindowController.swift
    WindowSplitController.swift
    WindowRouting.swift
    WindowActions.swift

  Toolbar/
    ToolbarController.swift
    ToolbarCatalogue.swift
    ToolbarState.swift

  Navigator/
    SidebarController.swift
    SidebarFooterView.swift
    NavigatorController.swift
    NavigatorOutlineView.swift
    NavigatorRowView.swift
    NavigatorSectionRowView.swift
    FileTree/
      FileTree.swift
      FileNode.swift
      DirectoryScanner.swift
      DirectoryWatcher.swift

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

  Library/
    LibraryContentView.swift
    LibraryView.swift
    LibraryHeaderView.swift

  LaunchPanel/
    LaunchPanelController.swift
    LaunchPanelView.swift
    LaunchPanelHeaderView.swift
    RecentSectionView.swift
    RecentRowView.swift

  Components/
    FileCardView.swift
    FolderCardView.swift
    FolderStackView.swift
    ThumbnailView.swift
    LibraryGridView.swift

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

A `WorkspaceSession` is the mutable browsing state of one native tab or standalone
window:

```text
WorkspaceSession
  root: URL              the workspace; only open(_:) moves it
  mode: WorkspaceMode    where this session points; only navigation moves it
  pdfSession: PDFSession?
  navigation history
```

`WorkspaceMode` is the session's single location coordinate:

```swift
enum WorkspaceMode { case library(URL), reading(URL) }
```

Its two cases are the two things the detail region can be, which is why
`WindowSplitController` switches on this and nothing else. `pdfSession` is
non-`nil` exactly while the mode is `.reading`, so every "does a PDF command
apply" check keeps asking it.

The root library is the workspace home. It lists the root's folders and PDFs and
adds a Recents section above them. Nested folder libraries omit that section.

The two properties are not peers, and the method pair says so: `open(_:)` moves
`root` and resets history, `navigate(to:)` moves `mode` and records it. Every
`navigate` caller passes `in: root`, so browsing cannot silently re-root the
workspace behind the navigator.

Multiple `WorkspaceSession` instances may reference the same workspace root. Their
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
  owns one WorkspaceSession, ToolbarController, and WindowSplitController

WindowSplitController
  owns the AppKit navigator/detail/inspector composition
  hosts LibraryContentView for library presentation
  installs PDFReaderController directly for reading
  hosts PDFInspectorView inside the native inspector split item

SidebarController
  owns the native navigator and hosts the SwiftUI footer accessory
```

Each native tab has its own `NSWindow` and `NSWindowController`, so each tab
also has its own toolbar, split controller, sidebar controller, and reader
controller. Native tab grouping controls presentation; it does not create a
shared controller tree.

`WorkspaceSession` and `PDFSession` remain the authoritative state owners. Rendering
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
4. Observable state crosses as `WorkspaceSession`, `PDFSession`, or the narrow
   `PDFReaderPresentationState`; none exposes a framework view.
5. Intent returns to the shell through `WindowActions`, an immutable,
   framework-neutral closure value.

`WindowActions` is the complete content-to-shell API. The name means
window-*scoped*, not window-*executed*: opening a tab happens next to this
window, choosing a location opens relative to it, and search targets this
window's document — even though `AppDelegate` performs several of them.

```swift
struct WindowActions {
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

`OpenRequest` is the single normalized input for pointing a session somewhere:

```swift
struct OpenRequest {
    let workspaceRootURL: URL
    let mode: WorkspaceMode
}
```

- A folder request uses that folder as the workspace root and shows it.
- A PDF request uses the PDF parent directory as the workspace root and reads
  the PDF.
- The factories standardize URLs. `folder(_:)` and `pdf(_:)` establish a
  workspace; `folder(_:in:)` and `pdf(_:in:)` move within an existing one.

`AppDelegate` resolves Finder, menu, recent-item, new-window, and new-tab opens.
`Cmd-N` presents the location picker and creates an independent window only
after a selection. `Cmd-T` creates a native tab that inherits the current root
and lands on its root library.

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
commands, validates menu and toolbar items, and projects `WorkspaceSession` changes
into the title, represented URL, recents, toolbar state, and visible content.

The toolbar is split by reason to change:

- `ToolbarCatalogue` is pure data: which items exist, their labels, symbols,
  commands, and which require an open PDF. Adding or renaming a button is an
  edit here alone.
- `ToolbarController` owns `NSToolbarDelegate`, item construction, and search
  presentation. It stores no application state.
- `ToolbarState` is the immutable value the toolbar is rendered from.

`WindowController` derives a fresh `ToolbarState` from whichever object owns
each value — the session for navigation, the reader for zoom, the split
controller for the inspector — and calls `ToolbarController.render(_:)` after every
session change. Do not reintroduce per-change `update` methods on the toolbar;
they require it to mirror state it does not own.

Enabled state is deliberately *not* part of that render pass. Top-level toolbar
items self-validate through `WindowController.canPerform(_:)`, which AppKit
calls whenever it is about to display them, so enabled state has exactly one
home. `render(_:)` sets only what validation has no hook for: item visibility,
and the subitem and selection state of `NSToolbarItemGroup`s, whose
`autovalidates` is off because AppKit validates a group as a single unit.

Toolbar customization autosaving is enabled in Release and intentionally
disabled in DEBUG. Persisted toolbar and split-view identifiers are
compatibility keys and do not need to match current type names.

Menus and toolbar items target the same small `@objc` methods on
`WindowController`. Back/forward navigation over `WorkspaceMode` belongs to
`WorkspaceSession`; page navigation inside the current PDF belongs to
`PDFReaderController` and PDFKit.

## Navigator

The navigator separates file data, outline projection, and row drawing:

```text
FileTree      model: the node tree for one root, kept in sync with disk
  FileNode      one directory or PDF; scans lazily, reconciles in place
  DirectoryScanner   one directory's PDFs and subdirectories, sorted
  DirectoryWatcher   FSEvents stream over the whole subtree
NavigatorController  projection: outline data source, selection, commands
  NavigatorOutlineView   command-click interception
  NavigatorRowView       icon + name
  NavigatorSectionRowView  workspace-root group row
```

`FileTree` owns file data and imports no AppKit, so the tree and its
reconciliation are testable without a view. `NavigatorController` owns no file
data: it answers outline-view queries from the tree and applies the tree's
deltas. This is the split the ownership table above already implied but the
original single controller did not honor.

Directory scanning remains lazy and is deliberately **synchronous**.
`isItemExpandable` answers from the node's kind and never reads a directory, so
a large folder costs nothing until it is opened; a folder that *is* opened scans
during the data-source query, which is tens of microseconds on a local volume
and lets `numberOfChildrenOfItem` return a true count on the first ask. Do not
reintroduce asynchronous loading with a sometimes-async completion handler: that
shape produced a reveal/load race and an empty-first-expansion artifact.
`FileNode.children` is the single place to become asynchronous if a network
volume ever justifies it, and that change needs a placeholder row.

Live updates are delta-based. `FileTree` rescans the directories it has
loaded and publishes per-directory index sets; `NavigatorController` applies them
with `removeItems(at:inParent:)` and `insertItems(at:inParent:)`. Node identity
is load-bearing: a path that survives a rescan keeps its existing
`FileNode`, which is what preserves expansion state and selection.
Rebuilding the tree, or falling back to `reloadData()`, discards both. For the
same reason `FileTree` publishes deltas through a callback rather than
`@Observable` — observation reports *that* something changed, which is the wrong
granularity for an outline view.

The outline has two roots: a virtual Recents row and the workspace tree. The
Recents row currently returns to the root library; selecting a folder shows its
library, and selecting a PDF opens the reader. Every move goes through
`WorkspaceSession`, so Back and Forward cover both folder and PDF navigation.

Modifier keys are handled in the event layer. `NavigatorOutlineView` resolves
command-click in `mouseDown` before selection runs, so the delegate methods never
consult `NSApp.currentEvent`; reading modifiers there only works for mouse input
and misbehaves for keyboard and accessibility-driven selection.

`SidebarController` hosts `SidebarFooterView` below the native outline.
`SidebarHeaderView` still exists in source but is temporarily disconnected; it
must not be described as current UI. AppKit continues to own sidebar material,
scrolling, selection, and responder behavior.

## Reader and Search

`PDFReaderController` owns the `PDFView` and rendered selections. `PDFSession`
owns the document, search operation, matches, current match, and reading
position. Global commands call controller or session capabilities rather than
reaching into a raw `PDFView`.

`PDFReaderPreview` is a DEBUG-only `NSViewControllerRepresentable` adapter for
the canvas. It is not part of production composition.

`WindowSplitController` owns the native inspector split item and hosts
`PDFInspectorView` there. The inspector is SwiftUI because PDFKit supplies its
document data but the app owns this presentation. Its three sections consume
the current `PDFDocument` directly:

- `PDFThumbnailsView` renders page thumbnails and returns page-selection intent.
- `PDFOutlineView` renders the PDF outline and returns outline-selection intent.
- `PDFInfoView` presents document metadata and current reader status.

`WindowSplitController` owns inspector presentation and exposes it as
`inspectorSection`, which is `nil` while the inspector is collapsed. It signals
changes with a payload-free callback; `WindowController` then reads the current
value while building `ToolbarState`. The native reader-panel group selects
exactly one matching segment, or none when the value is `nil` — a state the
optional makes unrepresentable rather than merely unlikely.

The private `PDFView` never crosses into SwiftUI. `PDFReaderController` performs
page and outline navigation, observes PDFKit page/scale notifications, and
publishes only `PDFReaderPresentationState` for current-page highlighting and
reader status. Trackpad magnification belongs to PDFKit's nested scroll view,
so the controller observes its magnification-start notification and leaves
`autoScales` before publishing the new zoom mode. This projection is
presentation state, not a second owner of the document or reading position.

On macOS 26 and later, the detail split item allows native sidebars and
inspectors to overlay it and adjusts its safe area. Library content uses
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

## Dictionary

These terms have one meaning each. Use them exactly; do not introduce a synonym
for a term that already exists.

| Term | Means | Does not mean |
|---|---|---|
| **Workspace** | a directory being browsed | a window, a tab, or a runtime object |
| **Session** | live state of browsing one workspace: root, selection, history | anything on screen |
| **Window** | the AppKit shell. A native tab *is* an `NSWindow` | the state inside it |
| **Shell** | window furniture: window, toolbar, menus, split layout | the content filling those regions |
| **Content** | what fills a shell region | the region itself |
| **Navigator** | the file-tree sidebar | the file tree data (that is `FileTree`) |
| **Reader** | the PDF viewing surface | the PDF document (that is `PDFSession`) |
| **Inspector** | the right-hand split region | |
| **Detail** | the middle split region. Always shows either the reader or the library | a container type — no such class exists |
| **Library** | the view of a workspace's contents, shown in detail when no PDF is open | the folder itself (that is the workspace) |
| **Mode** | which of those two the detail region is showing, and pointed where | a UI toggle the user flips |
| **Recents** | recently opened PDFs shown on the root library | a separate library mode |

Because a native tab is an `NSWindow`, "window" and "tab" would otherwise name
the same runtime object. The app resolves this by using **window** for the
AppKit shell and never naming its own types after tabs. `TabActivation` is the
sole exception: it means foreground or background from the user's point of
view, where "tab" is the honest word.

**Workspace is a domain word; Library is a UI word.** The folder being browsed
is a workspace (`WorkspaceSession`, `WorkspaceDocument`, "Recent Workspaces").
The view showing what is in it is the library. No type should use "Workspace"
to name a view.

**The library must never own navigation.** It gets no breadcrumbs and no back
stack. A folder card sends intent to `WorkspaceSession`, exactly like the same
folder in the navigator. `WorkspaceMode` is the single value Back and Forward
record.

## Naming Rules

A type's **suffix** says what kind of object it is:

| Suffix | Means |
|---|---|
| `Controller` | owns an AppKit object's lifecycle |
| `View` | draws |
| `Session` | mutable state with a lifetime |
| `Store` | persistence |
| `State` | an immutable snapshot passed to a renderer |
| `Actions` | a value carrying closures, no framework objects |
| `Catalogue` | static declarative data |
| `Scanner`, `Watcher` | single-purpose worker |

A type's **prefix** says which feature it belongs to: `Navigator`, `Reader`,
`Inspector`, `Workspace`, `Window`, `Toolbar`, `LaunchPanel`.

A type's name must be unambiguous **where it is used**, not where it is
defined. Swift has no per-folder namespace: at a call site the reader sees
`RowView`, never `Navigator/RowView`. A prefix earns its place when any of
these hold:

1. The bare name would collide with a framework type — `NavigatorOutlineView`
   against `NSOutlineView`.
2. The bare name would collide with another type here — `NavigatorRowView`
   against `RecentRowView`, `NavigatorOutlineView` against `PDFOutlineView`.
3. The bare name means nothing alone — `Controller`, `State`, `Actions`.
4. The prefix makes the feature findable. Typing `Navigator` in open-quickly
   should return the whole feature. Grouping by name is a real benefit, not
   redundancy, and it justifies a prefix even when nothing collides.

Matching the directory is usually the result of those rather than the goal.

Three further exceptions, each deliberate:

- **Generic workers carry no feature prefix.** `DirectoryScanner`,
  `DirectoryWatcher`, `NavigationHistory`, and `OpenRequest` describe work or
  values, not features, and would be equally at home elsewhere.
- **`PDF` is a domain qualifier, not a feature prefix.** It says which kind of
  document the type is about. `PDFThumbnailsView` in `Inspector/` and
  `PDFSession` in `Reader/` are correct; renaming them to `Inspector*` would
  describe where they live rather than what they handle.
- **`Sidebar` is the navigator's container region** — the scroll view, the
  footer, and the split item that holds them. It is part of the navigator's
  vocabulary, not a separate feature, which is why `SidebarController` lives in
  `Navigator/`.

Anything else named for one feature while sitting in another feature's
directory means either the name or the location is wrong.

`Shell` stays in the dictionary as the shell/content distinction, but no type
carries the name. It describes a boundary, not an object — the same reason
`Detail` has no class.

File names match their primary type.

## Directory Rules

**Directories group by feature. A directory groups by kind only when the thing
has no single owning feature.**

| Directory | Kind | Why it is by-kind |
|---|---|---|
| `Session/` | domain state | no feature owns it; every feature reads it |
| `Stores/` | persistence | app-wide. Feature-private persistence stays with its feature |
| `Components/` | UI | shared across features |

Everything a feature owns lives with that feature, including its domain types:
`FileTree` under `Navigator/`, `PDFSession` under `Reader/`. Nesting a
subdirectory inside a feature is a **crowding** decision, not an architectural
one — `Navigator/FileTree/` exists because that directory reached ten files.
Roughly ten is the threshold; below it, keep the feature flat.

## Method Verbs

Two verbs, and the distinction is a safety property rather than a style:

| Verb | Means | Safe to call twice? |
|---|---|---|
| `render` | make yourself match current truth | **yes** — idempotent by contract |
| `apply` | consume something that lands exactly once | **no** |

`NavigatorController.apply(_ deltas:)` is the case that matters:
`removeItems`/`insertItems` index against a specific before-and-after state, so
a second call corrupts the outline view. Anything named `render` may be called
as often as convenient — that is what lets every change converge the whole
window without callers tracking what they already did.

A bare `update()` says nothing either way and should not appear.
`updateWindowSubtitle()` is fine: verb plus a specific target names its own
scope.

## Non-Goals

- A globally unique workspace instance for every root URL.
- Shared mutable tab sessions or UI controllers.
- A custom tab strip or parallel SwiftUI window system.
- A protocol, coordinator, or service for a single concrete implementation.
- Splitting cohesive controllers solely to reduce line counts.
- Treating one PDF as the entire application model.
