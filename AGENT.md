# PDF Navigator Agent Notes

PDF Navigator is Rotem's Swift/macOS learning project. Rotem is experienced
with React, TypeScript, application architecture, and data flow, but is newer
to Swift, AppKit, SwiftUI, and Apple's document/window frameworks.

## Source Of Truth

Read these before making product or architecture decisions:

- [docs/product-requirements.md](docs/product-requirements.md)
- [docs/architecture.md](docs/architecture.md)

`product-requirements.md` owns product intent. `architecture.md` owns technical
direction. If they conflict with older code, treat the docs as the desired
direction and the code as legacy/current implementation.

## Working Agreement

Unless Rotem explicitly requests implementation:

- Inspect current files and the working-tree diff first.
- Explain causes before fixes.
- Separate correctness problems from preferences.
- Connect Swift concepts to React or TypeScript when useful.
- Do not modify files during a diagnosis or review.

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

## Current Direction

The intended architecture is AppKit-first for the macOS shell:

- AppKit owns app/document opening, native windows, native tabs, toolbar,
  sidebar split behavior, and command routing.
- PDFKit owns PDF rendering and PDF operations.
- SwiftUI is optional for contained views such as welcome screens, settings,
  and simple panels.

The framework boundary is strict:

- Embed SwiftUI with `NSHostingController` or `NSHostingView`.
- Pass observable domain state and the framework-neutral `WindowActions`
  value into hosted content.
- Do not expose AppKit windows, views, controllers, responders, or toolbar
  objects to SwiftUI.
- Keep `NSViewControllerRepresentable` adapters preview-only when production
  AppKit composition can install the controller directly.

Do not expand stale SwiftUI `WindowGroup`/`WindowBridge` patterns unless the
task explicitly targets the current implementation as a short-term fix.

## Verification

Use Xcode build/diagnostic tools when available. Do not claim visual
verification unless Rotem explicitly asks for it and it was actually performed.
