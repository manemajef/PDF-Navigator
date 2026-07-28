# PDF Navigator

PDF Navigator is a native macOS PDF reader for navigating collections of
related documents. It is also Rotem's Swift learning project.

Rotem is experienced with React, TypeScript, application architecture, and
data flow, but is new to Swift and Apple's frameworks. Explain unfamiliar
Swift concepts and challenge names or structures that import the wrong
semantics from React or Python.

## Working agreement

### Coaching and review

Unless Rotem explicitly requests implementation:

- Inspect current files and the working-tree diff first.
- Explain causes before fixes.
- Separate correctness problems from preferences.
- Connect Swift concepts to React or TypeScript when useful.
- Do not modify files during a diagnosis or review.

### Implementation

When Rotem requests implementation:

- Treat naming and organization as design decisions.
- Push back when a proposed Swift name misstates ownership or lifecycle.
- Prefer the minimum complete implementation.
- Avoid speculative wrappers, protocols, directories, compatibility branches,
  and defensive code written only "just in case."
- Extract shared behavior only when real duplication or ownership confusion
  exists.
- Preserve unrelated and uncommitted user changes.
- Report what was built and what still requires manual verification.

## Product model

Each native window or tab is one independent workspace session:

- **Workspace:** the directory tree shown in that tab.
- **Current PDF:** the document displayed in that tab.
- **Document navigation:** back and forward between selected PDFs.
- **Page navigation:** PDFKit navigation inside the current PDF.

Document and page navigation are separate histories.

Opening a PDF infers its parent directory as the workspace. Selecting a nested
PDF does not change the workspace root. A PDF opened in another tab inherits
the source workspace.

The app is read-only and should feel like Preview plus a directory-aware
sidebar, not like a general-purpose file manager.

## Source organization

The source root contains the types that define or coordinate one application
scene:

```text
PDFNavigator/
├── PDFNavigatorApp.swift
├── WorkspaceSplitView.swift
├── WorkspaceSession.swift
├── WorkspaceActions.swift
├── WorkspaceCommands.swift
├── WorkspaceWindowCoordinator.swift
├── UI/
│   ├── SidebarView.swift
│   ├── PDFReaderView.swift
│   ├── WorkspaceToolbar.swift
│   └── WorkspaceWelcomeView.swift
└── Core/
    ├── NavigationHistory.swift
    ├── PDFDirectoryScanner.swift
    ├── PDFReaderController.swift
    ├── PDFTreeNode.swift
    └── ReadingPositionStore.swift
```

Do not recreate `App/`, `Workspace/`, `Navigator/`, or `Reader/` merely for
taxonomy. Add another directory only when current responsibilities form a
real, nameable cluster.

### Ownership

- `PDFNavigatorApp` declares scenes and application commands.
- `WorkspaceSplitView` is the visible `NavigationSplitView` skeleton and wires
  one scene's session, reader, actions, picker, and window edge.
- `WorkspaceSession` owns workspace loading, selected PDF, document history,
  and lazy tree updates. It contains no SwiftUI view code.
- `WorkspaceActions` is the focused-scene capability contract shared by menus
  and toolbar content.
- `WorkspaceWindowCoordinator` is the only general `NSWindow` escape hatch.
- `UI/` contains views and narrowly scoped PDFKit/AppKit presentation adapters.
- `Core/` contains non-view state, PDFKit behavior, filesystem behavior,
  persistence, and pure tree operations.

Views receive state and actions. They should not scan directories, construct
PDF documents, mutate navigation history, or persist data.

## Native framework decisions

### Windows and tabs

- Use `WindowGroup`; do not migrate to `DocumentGroup`.
- One SwiftUI scene creates one independent `WorkspaceSession`.
- Native tabs are grouped `NSWindow` instances.
- AppKit is required only to acquire the backing window, join an explicitly
  opened scene to a source tab group, observe toolbar visibility, and service
  native tab responder actions.
- Never persist `NSWindow.windowNumber`.

### Sidebar

- Use `NavigationSplitView`, `List`, `.listStyle(.sidebar)`, and native
  `DisclosureGroup` rows.
- Do not paint a custom sidebar background or simulate system glass.
- Let macOS choose its version-appropriate sidebar material and shape.
- SwiftUI hierarchy views render supplied data; they do not lazily discover
  filesystem children.
- Scan one directory level on expansion. Never recursively enumerate an
  unknown workspace such as `~/` on the main actor.
- The optional footer remains compiled behind `showsFooter: false`. It is
  reserved for future directory navigation and workspace actions.

### Reader

- Keep a single `PDFView` alive while switching documents.
- `PDFReaderController` owns PDF document creation, a small bounded document
  cache, incremental PDFKit search, read-only annotation preparation, PDFKit
  commands, and reading-position persistence.
- PDFKit owns rendered-page caching and page/history/zoom behavior.
- Copy and Select All remain on the AppKit responder chain.

### Search and chrome

- Use SwiftUI `.searchable` for toolbar search presentation.
- When the toolbar is hidden, use the native soft top scroll-edge effect where
  available.
- The deployment target is macOS 15. Newer appearance APIs need one localized
  availability branch; do not scatter compatibility guards through views.

## State and Swift style

- Model mutually exclusive workspace phases with an enum.
- Use `guard` for genuine behavior-boundary early exits. Repeated guards in
  views usually indicate that the owning state or action contract is wrong.
- Derived capabilities such as `canGoBack` or `hasDocument` belong with the
  state that can answer them.
- Keep AppKit and PDFKit objects on the main actor unless an API explicitly
  supports another isolation domain.
- Filesystem enumeration runs through explicit concurrent entrypoints and
  returns Sendable value models.

## Development and verification

`DEMO_DIR` is the development workspace. Debug builds may open
`DEMO_DIR/micro3-sylabus.pdf`; release behavior must not depend on that path.

Build with:

```sh
env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -quiet \
  -project PDFNavigator.xcodeproj \
  -scheme PDFNavigator \
  -configuration Debug \
  -derivedDataPath /tmp/PDFNavigator-Codex-DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

During a large migration, build once per behaviorally destructive phase rather
than after every edit. Always run `git diff --check` at the end.

Do not use Computer Use or claim visual verification unless Rotem explicitly
requests it. Rotem performs the final manual checks for sidebar appearance,
toolbar-hidden chrome, tab creation/grouping/detaching, lazy expansion,
position restoration, and smooth PDF switching.
