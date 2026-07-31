# Roadmap

**Guiding principles**
- AppKit owns the chrome/machinery (windows, tabs, toolbar, menus, navigation tree, PDFView). SwiftUI owns design-heavy content surfaces that get restyled often (welcome page, folder page, sidebar action bar). Iterate UI in the SwiftUI leaves.
- The responder chain *is* the command layer — menu items, toolbar, and shortcuts all target the same `@objc` actions. No parallel abstraction on top.
- Refactor opportunistically (when already touching a file), never as a gate before fixes/features.

## Pre Release

### 1. Quick splits — one sitting, do first

- [ ] (refactor) move `WorkspacePlaceholderController` out of `WorkspaceWindowController.swift` into its own file (drops the "god file" from ~490 to ~350 lines)
- [ ] (refactor) move `installMainMenu` + Open Recent menu delegate out of `AppDelegate` into `MainMenu.swift` (AppDelegate drops to ~200 lines of actual lifecycle)
- [ ] (refactor) make sure only true workspace-related files live in `Workspace/*` (placeholder/welcome controller moves out as part of the split)

### 2. Fixes — search freeze first, it's the most user-hostile

- [ ] (fix) search freeze — root cause identified in `PDFSearchController`:
  - `updateQuery` starts `beginFindString` without `cancelFindString()` on the in-flight find; `isContinuous` search field means overlapping finds on every keystroke
  - `appendMatch` reassigns `pdfView.highlightedSelections = matches` on **every** match → O(n²) main-thread work on common queries
  - fix: cancel before starting a new find; buffer matches and batch the `highlightedSelections` assignment (on `PDFDocumentDidEndFind`, or throttled)
- [ ] (fix) `enter` to move to next match — falls out of the search-field action once distinguished from continuous changes (field's action already fires on return)
- [ ] (fix) navigation control
  - [ ] disabled when it can't navigate
  - [ ] able to navigate back to welcome page
- [ ] (fix) `cmd-n` opens new workspace in new window, `cmd-shift-n` opens new workspace in new tab
- [ ] (fix) fixed width on launch logic
- [ ] (fix) bg should be whiter in light mode (maybe dark too) so sidebar is distinguished
- [ ] (fix) titlebar label should be smaller

### 3. Welcome page → SwiftUI (the strategic refactor + fix in one)

- [ ] (refactor) rebuild welcome/placeholder page as SwiftUI via `NSHostingController` — replaces ~140 lines of stack views/constraints, and makes visual iteration cheap where it matters
- [ ] (fix) refine welcome page UI (do it in SwiftUI, not before the port)
- [ ] (feat) folder page: shows recents from that folder, looks different from welcome page — cheap once welcome page is a SwiftUI leaf

### 4. Features

- [ ] (feat) separate menu bar items for recent workspaces and recent files
- [ ] (feat) optional toolbar items for available commands (zoom related, new workspace, new window, etc.)
- [ ] (feat) sidebar shows content underneath when content is zoomed and scrolled
- [ ] (feat) new tab button should look like new tab; the plus button should open a new workspace (probably)
- [ ] (feat) sidebar bottom action bar: folder navigation + search functions (go to folder, go to parent, search in folder) — good SwiftUI leaf, hosted below the outline view in the same split pane
- [ ] (feat) new icon

### Opportunistic — only when already touching the file

- [ ] (refactor) move the toolbar delegate extension to its own `WorkspaceToolbar.swift` (borderline — it's already a clean extension)
- [ ] (refactor) root entry-point file (`App.swift` / `PDFNavigator.swift`) — cosmetic, `AppDelegate.main()` already does the job
- [ ] (refactor) if navigator row design gets fancy (badges, thumbnails, hover actions): keep `NSOutlineView` machinery, put SwiftUI row content inside the cell via `NSHostingView`

### Done / already true

- [x] (feat) `cmd-f` for search — already wired via Find… menu → `beginSearch`; verify it feels right after the freeze fix
- [x] (refactor) menu item commands use the same underlying functions as the UI — already true via responder chain (`validateMenuItem` handles enable/disable)
- [x] (refactor) `build_dir` in project dir and gitignored — `.build/` already ignored

### Decided against (for now)

- ~~remove AppKit boilerplate that can be avoided~~ — what's there is load-bearing protocol conformances (toolbar delegate, outline data source); contained, won't grow, no UI payoff in chasing it
- ~~organized construct/API layer of public commands~~ — the responder chain already is this; a parallel layer is the boilerplate we're trying to avoid
- ~~split `NavigatorController` / move tree to SwiftUI~~ — 361 cohesive lines; lazy loading on expand, programmatic reveal/expand/scroll, and cmd-click modifier detection are all things SwiftUI's `List`/`OutlineGroup` handles poorly. The tree is behavior-heavy chrome, not a design surface — exactly what we moved to AppKit for
- ~~broad "elegance" review (abstractions, separation of concerns)~~ — at ~2,400 lines the bigger risk is refactoring ahead of need; revisit only if a concrete pain shows up
