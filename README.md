# PDF Navigator

PDF Navigator is a native macOS PDF reader for people who work with
collections of related documents. It combines a Preview-style reading
experience with a workspace sidebar for moving quickly between PDFs in the
same directory tree.

> Preview is excellent for reading one document, but it does not provide a
> fast way to navigate surrounding lecture notes, exams, homework, and
> solutions. PDF Navigator turns the containing folder into a lightweight
> reading workspace.

## Product Direction

PDF Navigator is directory-based. In this project, a **workspace** means the
hosted root directory, not AppKit's `NSWorkspace` type.

- Opening a PDF infers its parent directory as the workspace and selects that
  PDF.
- Opening a folder creates a workspace without selecting an arbitrary PDF.
- Native tabs are first-class for keeping related PDFs open side by side.
- The sidebar is part of the product, not a general-purpose file manager.
- PDF rendering and reader interactions are powered by PDFKit.

## Current Capabilities

- Open a PDF or directory and navigate the surrounding PDF tree.
- Open PDFs in native macOS tabs, including background tabs.
- Read PDFs continuously with fit, actual-size, and manual zoom controls.
- Search within the current PDF and move between matches.
- Restore the last reading position for previously opened PDFs.
- Show thumbnails, table of contents, and document information in a native
  inspector panel populated with SwiftUI.
- Reopen recent PDFs and workspaces from the launch panel.

## Architecture

PDF Navigator intentionally uses AppKit and SwiftUI together:

- **AppKit owns application structure:** document and window lifecycle, native
  tabs, the toolbar, split-view geometry, menus, and command routing.
- **SwiftUI populates content:** the launch panel, workspace home, cards,
  headers, footers, thumbnails, table of contents, and document information.
- **The navigator is an AppKit exception:** its hierarchical file tree uses
  `NSOutlineView`, where native outline behavior is a better fit than SwiftUI.
- **PDFKit owns PDF behavior:** `PDFDocument` supplies pages, outlines,
  thumbnails, metadata, and search results; `PDFView` renders and navigates the
  current document.

Each native tab has a `TabSession` for its root directory, selected PDF, and
navigation history. A `PDFSession` owns the current document, search state, and
saved reading position. `PDFReaderController` is the narrow AppKit adapter that
renders that session into a private `PDFView`.

`WorkspaceDocument` is lifecycle glue for `NSDocumentController`: it gives each
window, including a tabbed window, an AppKit document owner and carries its open
request. It does not represent a user-editable document format and cannot be
saved.

## Current Status

PDF Navigator is an early preview and is not yet distributed as an installer.
The structure is still evolving, but the AppKit-shell/SwiftUI-content boundary
above reflects the current implementation and intended direction.

## Development

PDF Navigator targets macOS 15 or later.

Open `PDFNavigator.xcodeproj` in Xcode, or build and run the debug app from the
command line:

```sh
./script/build_and_run.sh
```
