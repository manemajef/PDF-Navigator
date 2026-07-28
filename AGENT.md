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

The source tree follows visible product responsibilities:

```text
PDFNavigator/
├── PDFNavigatorApp.swift
├── WorkspaceView.swift
├── WindowBridge.swift
├── Workspace/
│   ├── WorkspaceSession.swift
│   ├── WorkspaceActions.swift
│   ├── WorkspaceCommands.swift
│   ├── WorkspaceToolbar.swift
│   ├── WorkspaceLaunch.swift
│   └── NavigationHistory.swift
├── Navigator/
│   ├── NavigatorView.swift
│   ├── NavigatorItem.swift
│   └── DirectoryScanner.swift
└── Reader/
│   ├── PDFReaderView.swift
│   ├── PDFSearch.swift
│   └── ReadingPositionStore.swift
```

Keep application entry and the one unavoidable AppKit boundary at the root.
Add a directory only for a real product responsibility, not to separate
"core," "UI," protocols, implementations, or other abstract categories.

### Ownership

- `PDFNavigatorApp` declares scenes and application commands.
- `WorkspaceView` is the visible `NavigationSplitView` skeleton. It composes
  feature views and wires the picker, focused commands, and tab launch.
- `WorkspaceSession` owns workspace loading, selected PDF, document history,
  and loaded directory contents. It contains no view code.
- `NavigatorView` renders session state and forwards selection or expansion
  intent. `DirectoryScanner` performs one-level filesystem reads off-main.
- `PDFReaderView` is the narrow PDFKit bridge. `PDFSearch` and
  `ReadingPositionStore` hold the two noisy reader behaviors worth separating.
- `WorkspaceActions` carries the focused session, reader handle, and tab
  actions to commands and toolbar content without mirroring PDFKit state.
- `WindowBridge` is the only general `NSWindow` escape hatch.

Views receive state and actions. They should not scan directories, construct
PDF documents outside the reader bridge, mutate navigation history, or persist
data.

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
- Show every non-hidden directory and PDF returned for the current level.
- Scan the root once, then scan one directory level off-main when its
  disclosure opens. Never recursively enumerate an unknown workspace such as
  `~/`.

### Reader

- Keep a single `PDFView` alive while switching documents.
- Let `PDFView` and `PDFDocument` own rendering, page navigation, zoom, and
  document lifetime. Do not add a second document cache without measured need.
- Search through PDFKit's asynchronous find API.
- Save page, position, and zoom only when switching or dismantling the reader.
- PDFKit owns rendered-page caching and page/history/zoom behavior.
- Copy and Select All remain on the AppKit responder chain.

### Search and chrome

- Use SwiftUI `.searchable` for toolbar search presentation.
- When the toolbar is hidden, use the native soft top scroll-edge effect where
  available.
- The deployment target is macOS 15. Newer appearance APIs need one localized
  availability branch; do not scatter compatibility guards through views.

## State and Swift style

- Use `guard` for genuine behavior-boundary early exits. Repeated guards in
  views usually indicate that the owning state or action contract is wrong.
- Ask the owning object for derived state; do not mirror PDFKit capabilities in
  a second observable model.
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

While this refactor is settling, build once per meaningful milestone rather
than after every edit. Add tests after Rotem approves the structure. Always run
`git diff --check` at the end.

Do not use Computer Use or claim visual verification unless Rotem explicitly
requests it. Rotem performs the final manual checks for sidebar appearance,
toolbar-hidden chrome, tab creation/grouping/detaching, lazy expansion,
position restoration, and smooth PDF switching.
