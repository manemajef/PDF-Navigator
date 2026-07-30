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

PDF Navigator is workspace-based:

- Opening a PDF infers its parent directory as the workspace and selects that
  PDF.
- Opening a folder creates a workspace without selecting an arbitrary PDF.
- Native tabs are first-class for keeping related PDFs open side by side.
- The sidebar is part of the product, not a general-purpose file manager.
- PDF rendering and reader interactions are powered by PDFKit.

The source of truth for product behavior is
[docs/product-requirements.md](docs/product-requirements.md).

The source of truth for technical direction is
[docs/architecture.md](docs/architecture.md).

## Current Status

PDF Navigator is an early preview and is not yet distributed as an installer.
The current implementation is being reworked toward the architecture described
in `docs/architecture.md`.

## Development

PDF Navigator targets macOS 15 or later.

Open `PDFNavigator.xcodeproj` in Xcode, or build and run the debug app from the
command line when the local scripts are available:

```sh
./script/build_and_run.sh
```
