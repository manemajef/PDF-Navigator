# PDF Navigator

PDF Navigator is a native macOS PDF reader designed around navigating collections
of related PDF files.

This is also a learning project. Its purpose is to help Rotem learn Swift,
SwiftUI, PDFKit, and native macOS application conventions while building a useful
application.

Rotem is experienced with React, TypeScript, application architecture, and data
flow, but is new to Swift and Apple's frameworks.

## Agent Working Agreement

### Default: coaching mode

Unless Rotem explicitly asks for implementation, act as a teacher and technical
guide.

- Inspect the current code before recommending changes.
- Explain unfamiliar Swift, SwiftUI, PDFKit, and AppKit concepts in detail.
- Connect new concepts to React or TypeScript when that comparison is useful.
- Break work into small steps that Rotem can implement manually.
- Prefer focused examples and partial snippets over complete files.
- Explain why an API or architectural choice fits the problem.
- Identify which files and types are likely to change before suggesting code.
- After Rotem implements a step, review the actual diff and explain any problems.

Do not silently implement an entire feature when the goal can be achieved through
guided development.

### Review mode

When asked to review or diagnose:

- Inspect the relevant files and current diff.
- Explain the cause of each issue before proposing a fix.
- Distinguish correctness problems from style preferences.
- Do not modify files unless Rotem also asks for implementation.

### Implementation mode

Modify project files only when Rotem explicitly asks for implementation, or when
the change is clearly mechanical, such as formatting, repetitive boilerplate, or
a small rename.

When implementing:

- Keep the change limited to the requested step.
- Avoid introducing abstractions that have not yet become necessary.
- Explain any important Swift or Apple-platform concepts used.
- Report exactly what changed and what was verified.
- Do not claim that the UI was manually tested unless it actually was.

## Product Vision

A student often keeps lecture notes, recitations, homework, exams, and solutions
as PDF files in one directory tree. Preview displays a single document well, but
it does not provide project-style navigation across the surrounding files.

PDF Navigator should make the directory containing the current PDF feel like a
lightweight document workspace.

### Primary user flow

1. The user opens a specific PDF.
2. The app displays that PDF.
3. The app treats the PDF's parent directory as the current workspace.
4. The left sidebar shows PDF files in that directory and its relevant
   subdirectories.
5. Selecting another PDF replaces the document in the current tab.
6. The user can move backward and forward through file-selection history.
7. The user can open a PDF in another native tab or window.

For example, a student reading `course-lecture-03.pdf` should be able to quickly
open `course-lecture-04.pdf`. A student should also be able to switch efficiently
between `exam-2024.pdf` and `exam-2024-solution.pdf`.

## Product Principles

- Prefer native macOS behavior over custom interaction patterns.
- Keep the reading experience minimal and distraction-free.
- Provide directory awareness without becoming a general-purpose file manager.
- Make movement between related documents fast.
- Keep PDF content read-only.
- Prefer standard SwiftUI, PDFKit, AppKit, and system components.
- Keep the architecture small and understandable while the project is young.

## Terminology and State Ownership

- **Current PDF:** the document displayed in a particular tab.
- **Workspace:** the directory tree shown in that tab's navigator.
- **Navigator:** the left sidebar containing the workspace's PDF hierarchy.
- **File history:** PDFs previously selected in the current tab.
- **Document navigation:** moving between PDFs.
- **Page navigation:** moving between pages inside one PDF.

Back and forward refer to file history unless explicitly stated otherwise.

Native macOS tabs are grouped windows, not custom in-app tabs. Each native tab or
standalone window represents an independent navigation session and owns:

- Its workspace root
- Its current PDF
- Its backward and forward file history
- Its expanded navigator directories
- Its sidebar and inspector presentation state

Application preferences and appearance settings may be shared across sessions.
The active workspace, PDF, and history must not be stored as global application
state.

### Workspace rules

- Opening a PDF from Finder or an open panel creates a session whose workspace is
  that PDF's parent directory.
- Selecting a PDF inside a workspace does not change the workspace root, even
  when the PDF is in a nested directory.
- Opening a navigator PDF in a new tab opens that PDF and inherits the originating
  tab's workspace.
- Changing the workspace affects only the active tab.
- Detaching a native tab into a window does not change its session.

## Core Interface

### Left sidebar: Navigator

The navigator should:

- Show PDFs in the workspace and its subdirectories.
- Show a directory only when it contains a PDF directly or through a descendant.
- Use native expandable directory rows.
- Highlight the current PDF.
- Sort entries using natural, human-readable filename ordering.
- Open a selected PDF in the current tab.
- Support opening a PDF in another native tab or window.

Later versions may add file renaming and a contextual menu. These operations
affect files on disk; they do not modify PDF contents.

### Center: PDF reader

The reader should:

- Use PDFKit.
- Display the current PDF clearly and efficiently.
- Preserve a read-only experience, including PDF form annotations where
  practical.
- Keep page navigation separate from document navigation.

### Right sidebar: Inspector

A later version may provide:

- Table of contents
- Page thumbnails
- Document information

This is not required for the first usable version.

### Toolbar and shortcuts

The initial toolbar should remain small and use native macOS conventions.
Candidate actions are:

- Toggle the navigator
- Move backward and forward through file history
- Open the current PDF in a new tab
- Open the current PDF in Preview
- Toggle the inspector when it exists
- Search when it exists

Toolbar customization should be deferred until the stable set of actions is
known. Keyboard shortcuts must follow macOS conventions and must not override
established system shortcuts.

Initial shortcut goals:

- `Command-T`: create a native tab and present the PDF picker
- `Command-N`: create an independent window
- `Command-O`: open a PDF
- `Command-[` and `Command-]`: move backward and forward through file history

Native tab traversal should use the standard shortcuts supplied by macOS.

## Project Organization

Organize source code by product feature rather than by technical layer:

```text
PDF Navigator/
├── App/
│   ├── PDFNavigatorApp.swift
│   └── AppCommands.swift              # Add when application commands exist
├── Workspace/
│   ├── WorkspaceView.swift
│   ├── WorkspaceSession.swift
│   └── NavigationHistory.swift        # Extract when history becomes substantial
├── Navigator/
│   ├── NavigatorView.swift
│   ├── PDFTreeNode.swift
│   └── PDFDirectoryScanner.swift
├── Reader/
│   └── PDFReaderView.swift
└── Assets.xcassets/

PDF NavigatorTests/
├── WorkspaceSessionTests.swift
├── NavigationHistoryTests.swift
└── PDFDirectoryScannerTests.swift

DEMO_DIR/
```

The intended dependency direction is:

```text
App -> Workspace -> Navigator
                 -> Reader
Navigator -> PDF tree and directory scanning
Reader -> PDFKit
```

The navigator and reader do not communicate directly. The workspace session
coordinates them.

### Organization rules

- Each native tab owns one workspace session.
- Keep filesystem discovery in `Navigator`.
- Keep PDFKit integration in `Reader`.
- Keep cross-feature coordination and per-tab state in `Workspace`.
- Keep scene creation and application commands in `App`.
- Prefer names that describe product responsibilities.
- Avoid generic `Managers`, `Helpers`, `Utils`, and global `Models` folders.
- Do not create a view model for every view by default.
- Introduce shared abstractions or protocols only when multiple concrete callers
  require them.
- Keep a small type in its owning feature until extracting it improves clarity.

## Development Environment

`DEMO_DIR` is the development workspace. It contains PDFs in nested directories.

During development, the app may automatically open:

`DEMO_DIR/micro3-sylabus.pdf`

This behavior is only a development convenience. It must be isolated so it does
not become normal release behavior.

Normal application behavior begins from a specific PDF and infers the workspace
from that PDF's parent directory. Choosing a directory directly is a secondary
workflow.

## Milestones

### L0 — Existing prototype

The repository currently demonstrates:

- A SwiftUI split view
- A flat list of PDFs from a selected directory
- PDF rendering through PDFKit
- Basic directory selection
- A read-only treatment of PDF annotations

Treat this as a prototype, not the final architecture.

### L1 — Usable navigation prototype

L1 is complete when:

- The development build opens the default demo PDF.
- Opening a PDF establishes its parent directory as the workspace.
- The current PDF appears in the center reader.
- The left navigator recursively displays relevant subdirectories and PDFs.
- Directories can be expanded and collapsed.
- Selecting a PDF opens it in the current tab without changing the workspace.
- Back and forward traverse file-selection history correctly.
- The navigator can be shown and hidden.
- The toolbar can be hidden while preserving a clean window appearance.
- The toolbar's new-tab action creates a native tab and presents the PDF picker.
- Opening a navigator item explicitly in a new tab inherits its originating
  workspace.
- Empty directories, unsupported files, and inaccessible files do not break
  navigation.
- The project builds without warnings introduced by project code.

### L2 — Native macOS workflows

After L1 is stable, add:

- Opening PDFs through normal macOS document workflows
- New-window behavior
- More complete native-tab behavior
- Keyboard shortcuts
- Context menus
- File renaming
- Open in Preview
- Changing the workspace
- Right inspector with outline and thumbnails
- Search
- Toolbar customization

### L3 — Distribution polish

Possible later work:

- Application icon
- Recent documents
- State restoration
- Sandboxing and persistent file permissions
- Error and empty-state polish
- Performance with large directory trees
- Default-PDF-reader setup and distribution concerns

## Learning Session Plan

Treat each session as a small, reviewable vertical step. Rotem should understand
and be able to explain the state and data flow introduced in a session before
starting the next one.

### Session 1 — Preserve the prototype while organizing it

Goal: establish the feature-oriented directory structure without intentionally
changing behavior.

- Rename `ContentView` to `WorkspaceView`.
- Rename `PDFLibrary` to `WorkspaceSession`.
- Move the application, workspace, and reader files into their owning folders.
- Keep one workspace session owned by each `WorkspaceView`.
- Build and manually confirm that the flat-folder prototype still works.

Learning focus:

- Swift files and modules
- Value types versus reference types
- `ObservableObject`, `@StateObject`, and object lifetime
- Why view-owned state is independent for each scene

### Session 2 — Start from a PDF

Goal: make a PDF URL, rather than a directory, the input that establishes a
session.

- Add an operation that opens a specific PDF.
- Derive the workspace root from that PDF's parent directory.
- Isolate the development-only default URL for
  `DEMO_DIR/micro3-sylabus.pdf`.
- Keep directory selection only as a secondary development workflow.
- Clarify the lifetime of security-scoped access before expanding file-opening
  behavior.

Learning focus:

- `URL` and filesystem APIs
- Initializers and methods with explicit responsibilities
- Application state versus development configuration
- macOS sandbox and security-scoped resource concepts

### Session 3 — Build the recursive navigator model

Goal: represent the workspace as a testable tree before building the full UI.

- Add `PDFTreeNode`.
- Add `PDFDirectoryScanner`.
- Recursively discover PDFs.
- Remove branches that contain no PDFs.
- Use natural filename ordering.
- Add focused scanner tests using temporary directories.

Learning focus:

- Enums, structs, and recursive data
- `FileManager`
- Pure transformations
- Error propagation
- Swift testing fundamentals

### Session 4 — Render and select from the navigator

Goal: replace the flat list with the recursive sidebar.

- Add `NavigatorView`.
- Render native expandable directory rows.
- Bind selection to the workspace session.
- Keep the workspace root fixed when selecting PDFs in nested directories.
- Preserve the current selection while directories expand and collapse.

Learning focus:

- SwiftUI bindings
- Recursive view composition
- Identity in SwiftUI lists
- One-way data flow

### Session 5 — Add document history

Goal: provide predictable backward and forward navigation between PDFs.

- Define the history invariants before implementing them.
- Add backward and forward stacks or an equivalent indexed history.
- Do not add duplicate entries when history itself changes the selection.
- Clear the forward branch after a new selection.
- Add focused unit tests for the history behavior.
- Connect toolbar actions only after the state behavior is tested.

Learning focus:

- State-machine thinking
- Collection operations
- Separating user intent from state mutation
- Testing navigation invariants

### Session 6 — Add native windows and tabs

Goal: create independent sessions using native macOS window tabbing.

- Create a new native tab that receives the chosen PDF and inherited workspace.
- Create a new independent window.
- Confirm that each tab has independent selection and history.
- Confirm that a tab opened from a nested PDF retains the originating workspace.
- Confirm that detaching and merging tabs preserves session state.
- Add application commands and standard keyboard shortcuts.

Learning focus:

- SwiftUI scenes and scene values
- Window lifetime
- Per-scene versus application-wide state
- SwiftUI and AppKit interoperability where needed

### Session 7 — Finish the L1 shell

Goal: complete and polish the first usable navigation experience.

- Finalize toolbar actions.
- Support showing and hiding the navigator.
- Support hiding the toolbar with an appropriate native appearance.
- Add useful empty and error states.
- Check inaccessible files and empty workspaces.
- Run the full build and focused tests.
- Perform the complete L1 workflow manually.

Learning focus:

- macOS commands and toolbar conventions
- Presentation state
- Error handling
- Accessibility and manual UI verification

Do not begin L2 feature work until the L1 completion criteria have been checked
against the running application.

## Non-goals for L1

Do not add these during L1 unless specifically requested:

- PDF annotation or content editing
- A general-purpose file manager
- Non-PDF file previews
- Cloud synchronization
- Tags or document databases
- Automatic semantic grouping of files
- A custom tab system
- Premature persistence or caching layers
- Broad design-system abstractions

## Decision Guidelines

When several approaches are possible:

1. Prefer native platform behavior.
2. Prefer the smallest design that satisfies the current milestone.
3. Prefer code Rotem can explain after implementing it.
4. Introduce abstractions only when a concrete duplication or ownership problem
   exists.
5. Separate filesystem state, navigation state, and PDF presentation state.
6. Confirm uncertain Apple API behavior through official documentation or a
   focused experiment.
