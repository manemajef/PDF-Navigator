# PDF Navigator Architecture

This document translates `product-requirements.md` into technical design rules.
If product requirements change, this document may need to change. Internal
implementation details may also change without changing product requirements,
as long as the user-visible behavior remains the same.

## Architectural Direction

PDF Navigator should use an AppKit-first macOS shell with focused SwiftUI use
only where it clearly helps.

The app needs native document opening, native window tabs, toolbar hiding and
customization, sidebar collapse behavior, responder-chain commands, and a
PDFKit reader. These are AppKit-native responsibilities. SwiftUI remains useful
for isolated views such as welcome screens, settings, or simple panels, but it
should not own the window/tab/toolbar/sidebar shell.

## High-Level Structure

```text
App/
  AppDelegate
  AppCommands

Workspace/
  WorkspaceDocument
  WorkspaceWindowController
  WorkspaceSession
  WorkspaceActions
  WorkspaceOpenRequest
  WorkspaceSplitViewController
  WorkspaceToolbar
  NavigationHistory

Navigator/
  NavigatorController
  NavigatorItem
  DirectoryScanner

Reader/
  PDFSession
  PDFReaderController
  ReadingPositionStore

Stores/
  RecentLocationsStore
```

Names may change during implementation, but the ownership boundaries should
remain stable.

## Framework Ownership

| Responsibility | Owner |
| --- | --- |
| App lifecycle and open-file handling | AppKit |
| Native windows and native tabs | AppKit |
| Toolbar construction, hiding, customization, validation | AppKit |
| Sidebar split, collapse, width autosave | AppKit |
| PDF rendering and PDF operations | PDFKit inside AppKit controller |
| Command routing and menu validation | AppKit responder chain |
| Welcome, settings, simple empty states | SwiftUI optional |
| Filesystem scanning | Service/value layer, off main actor where safe |
| Persistence and bookmarks | Store layer |

SwiftUI should not be the root architecture for native tabs or window chrome.

## Core Runtime Model

Each native tab is one workspace context.

```text
WorkspaceSession
  root: URL?
  selection: URL?
  pdfSession: PDFSession?
  directory tree/cache
  expanded directories
  PDF-to-PDF navigation history

PDFSession
  document
  search query and matches
  reading position
```

The window shell contains state that should feel shared across tabs:

```text
Window shell
  toolbar visibility
  sidebar visibility
  window size/position
  native tab bar
  toolbar customization
```

The app should not store one global current workspace or one global current PDF.
All document/workspace state is scoped to the active workspace tab.

## WorkspaceDocument

`WorkspaceDocument` is currently the read-only AppKit entry point that creates
one native tab. It retains the initial open request so AppKit can construct the
window, but it does not track later sidebar or history selection changes.
`WorkspaceSession` is the live source of truth.

Opening a PDF creates a `WorkspaceDocument` whose root is the PDF's parent
directory and whose selected PDF is the opened file.

Opening a folder creates a `WorkspaceDocument` whose root is that folder and
whose selected PDF is nil.

The document should disable unsupported save/revert commands unless a future
feature introduces real workspace files.

## WorkspaceWindowController

`WorkspaceWindowController` owns one native tab/window's shell and active
workspace UI.

Responsibilities:

- Create and configure `NSWindow`.
- Assign `tabbingIdentifier` and `tabbingMode`.
- Create and own the `NSToolbar`.
- Create and own the split view controller.
- Route toolbar and menu actions to the active workspace/reader controllers.
- Own one `WorkspaceSession`, which maintains root, selection, the current
  `PDFSession`, and PDF-to-PDF navigation history.
- Update window title, subtitle, represented URL, and recent items.
- Coordinate opening files/folders in the current tab, new tab, or new window.

Controllers read from the shared session and send mutations through its
methods. They must not cache copies of root or selection.

## NativeTabCoordinator

Native tabs should use AppKit `NSWindow` tabbing, not a custom SwiftUI tab bar.

The tab coordinator should isolate all tab-specific AppKit behavior:

- Mark the next opened workspace window as an explicit tab.
- Mark the next opened workspace window as an explicit separate window.
- Attach a newly created window to the frontmost compatible tab group.
- Respect `NSWindow.userTabbingPreference` for ordinary opens.
- Keep one-shot tab/separate-window flags from leaking if no window is created.

No regular view should call `addTabbedWindow` directly.

## WindowChromeState

Toolbar and sidebar visibility are window-shell concerns.

Toolbar visibility should be applied through the native window toolbar:

```swift
window.toolbar?.isVisible = isVisible
```

or the equivalent responder-chain toolbar toggle.

Sidebar visibility should be applied through the split view controller. If
multiple native tabs need shared sidebar visibility, the window/tab coordinator
must synchronize that state across the windows in the tab group.

Do not store toolbar/sidebar visibility inside a workspace model as if it were
document content.

## Workspace Open Flow

Use one resolver for all user-originated open requests:

```swift
enum WorkspaceOpenRequest {
    case pdf(URL)
    case folder(URL)
}
```

Resolution rules:

- PDF request: root is `pdf.deletingLastPathComponent()`, selected PDF is the
  PDF.
- Folder request: root is the folder, selected PDF is nil.
- Record recent workspace for both PDFs and folders.
- Record recent PDF for PDF requests and selected sidebar PDFs.
- Create or refresh security-scoped bookmark access for restored locations.

Open logic should not be duplicated in welcome views, menu commands, sidebar
context menus, and document controllers.

## Sidebar Architecture

The sidebar should use AppKit for native source-list behavior unless a later
experiment proves SwiftUI is simpler without losing native behavior.

Responsibilities:

- Display the current workspace root.
- Lazily enumerate directories.
- Track expanded directories per workspace tab.
- Track selected PDF per workspace tab.
- Restore committed selection if navigation is cancelled or fails.
- Provide context menu actions such as Open, Open in New Tab, Open in New
  Window, Show in Finder, and Open in Default App.

Directory scanning should remain lazy. Do not recursively enumerate arbitrary
large workspaces on open.

## Reader Architecture

`PDFSession` owns the selected URL, `PDFDocument`, search state, and reading
position. `PDFReaderController` owns `PDFView` and renders the session.

Responsibilities:

- Attach a `PDFSession` and display its document.
- Save and restore reading position through the session.
- Expose page navigation.
- Expose zoom commands.
- Expose share/print/default-app actions when relevant.
- Hide PDFKit implementation details from global app commands.

Commands should call reader capabilities:

```swift
reader.zoomIn()
session.pdfSession?.selectNextMatch()
reader.goToPreviousPage()
```

They should not reach through to a raw `PDFView` from app-level command code.

## Search Architecture

Search should be an AppKit toolbar/readers feature, not SwiftUI `.searchable`.

Use `NSSearchToolbarItem` in the native toolbar. It drives the current
`PDFSession`; the reader observes that session and renders search changes.

`PDFSession` owns:

- Current query.
- PDFKit find cancellation.
- Match collection.
- Selected match index.
- Next/previous result behavior.
- Result-count reporting when added to the UI.

`PDFReaderController` owns only the rendered selection and highlighted
selections in `PDFView`.

Changing the selected PDF must cancel search for the old document and clear or
re-run search according to the current product decision.

## Command Routing

Use the AppKit responder chain for native command routing and validation.

Global app/menu commands should resolve the active `WorkspaceWindowController`
from the key or main window, then ask it whether an action is available.

`WorkspaceActions` is limited to the four app-level operations needed by child
controllers: choose workspace, open PDF, open in a new tab, and create a tab.
It must not expose session state or framework views. Menu commands continue to
use small controller methods:

```swift
openWorkspace()
openPDFInNewTab(_:)
toggleSidebar()
toggleToolbar()
goBackInWorkspace()
goForwardInWorkspace()
zoomInPDF()
searchCurrentPDF(_:)
```

Document navigation and PDF page navigation must remain separate commands.

## Persistence

Persist these concepts separately:

- Recent workspaces.
- Recent PDFs.
- Restored workspace tabs.
- Reading positions per PDF.
- Toolbar customization.
- Window frame.
- Split view/sidebar width.

Use security-scoped bookmarks for durable access to user-selected files and
folders. Raw URLs are acceptable for current runtime state, but not as the only
restoration mechanism in a sandboxed macOS app.

Where possible, store paths relative to the workspace root:

```swift
struct WorkspaceSnapshot: Codable {
    var rootBookmarkID: UUID
    var selectedPDFRelativePath: String?
    var expandedDirectoryRelativePaths: Set<String>
}
```

## SwiftUI Usage Rules

SwiftUI is allowed where it reduces complexity:

- General welcome view.
- Workspace home view.
- Settings.
- Simple panels or popovers.
- Small static or form-like views hosted in AppKit.

SwiftUI should not own:

- Native window lifecycle.
- Native tab attachment.
- Toolbar customization.
- Toolbar visibility.
- Sidebar split/collapse behavior.
- PDFKit command routing.

If a SwiftUI view needs to trigger shell behavior, it should call a narrow
controller method rather than receiving `NSWindow`, `NSToolbar`, or `PDFView`.

## Technical Non-Goals

- A fake-native custom tab strip.
- A parallel SwiftUI and AppKit window system.
- A `DocumentGroup` architecture where one PDF is treated as the whole scene
  model.
- Passing raw `PDFView` through global command state.
- Persisting raw URLs as the only file-access restoration mechanism.
- Recursive eager scanning of arbitrary directory trees.

## Migration Direction From Current Code

The current SwiftUI `WindowGroup` architecture should be treated as temporary.
Future refactors should move toward:

1. AppKit app/document opening.
2. `WorkspaceDocument` or equivalent read-only document context.
3. `WorkspaceWindowController` with native toolbar and native tabs.
4. AppKit split/sidebar shell.
5. `PDFReaderController` owning all PDFKit operations.
6. Store-backed recents, bookmarks, and restoration.

During migration, avoid expanding the existing `WindowBridge` and
`WorkspaceActions` patterns. They are symptoms of the current mismatch between
SwiftUI scene ownership and native Mac shell behavior.
