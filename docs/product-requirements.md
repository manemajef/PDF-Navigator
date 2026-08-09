# PDF Navigator Product Requirements

This document is the source of truth for product intent. It describes what the
app is for, how users expect it to behave, and which decisions define the
product. Technical implementation details belong in `architecture.md`, and
unfinished work belongs in `roadmap.md`.

## Product Definition

PDF Navigator is a native macOS reader for working with collections of related
PDFs. It should feel like Preview plus a workspace navigator: a user can open
one PDF, immediately see nearby related PDFs, move between them quickly, and
open related files side by side in tabs.

The app is workspace-based. A workspace is a directory. A PDF is an optional
selected document inside that workspace.

Opening a PDF is a convenience entry point into a workspace: the app infers the
workspace from the PDF's parent directory and selects the opened PDF.

## Target Users

- Students studying from folders of lecture notes, exams, homework, and
  solutions.
- Researchers or readers who keep related PDFs in directory trees.
- Users who want Preview-like PDF reading without constantly returning to
  Finder.

## Core User Stories

As a user, I want to open a PDF with the app, then use the sidebar to navigate
between other PDFs in the same directory tree.

As a user, I want back and forward navigation to move between the workspace
home and PDFs I recently visited in the current tab.

As a user, I want to open a related PDF in a new tab so I can compare files,
for example an exam and its solution.

As a user preparing for an exam, I want to open a course folder such as
`micro3`, then browse `exams`, `lecs`, and `hw` without leaving the app.

As a user, I want windows, tabs, toolbar, and sidebar behavior to feel native to
macOS and consistent with apps like Finder, Preview, Safari, and Xcode.

## Product Model

| Concept | Meaning |
| --- | --- |
| Workspace | A directory that provides the navigation context. |
| Selected PDF | The PDF currently displayed in a workspace tab. Optional. |
| Workspace tab | One native tab containing one workspace context. |
| Window shell | The native macOS window chrome: toolbar, tab bar, sidebar visibility, size, and position. |
| Workspace navigation history | Back/forward history between workspace homes and selected PDFs in one tab. |
| PDF page history | PDFKit's internal document/page navigation inside the selected PDF. |

Workspace navigation and PDF page navigation are separate product concepts.

## Opening Behavior

| User Action | Expected Result |
| --- | --- |
| Open PDF | Open the parent directory as workspace and select that PDF. |
| Open folder | Open that folder as workspace with no selected PDF. |
| Open unrelated PDF from an existing tab | Replace the current tab's workspace with the PDF's parent directory and select the PDF. |
| Select PDF from sidebar | Keep the same workspace root and display the selected PDF. |
| Open PDF in New Tab | Create a new native tab in the same window, using the source workspace and selected PDF. |
| Open Recent PDF | Open its parent directory as workspace and select the PDF. |
| Open Recent Workspace | Open that workspace with no selected PDF. |

Opening a folder must not auto-select an arbitrary first PDF. If no PDF is
selected, the app shows a workspace home view.

## Window And Tab Behavior

`Cmd-N` opens the PDF-or-folder picker. A new native window is created only
after the user chooses a workspace or PDF.

`Cmd-T` opens a new native tab that inherits the current workspace and starts
with no selected PDF.

Native tabs are first-class. Users should be able to keep multiple related PDFs
open in one window and switch between them without losing the surrounding
workspace context.

Toolbar visibility, sidebar visibility, window size, and window position are
window-shell state. They should feel shared across tabs in the same native
window.

Sidebar contents, selected PDF, expanded folders, search state, and workspace
navigation history belong to the active workspace tab.

## Launch Panel And Library

When the app launches without an open workspace, a separate launch panel
appears. It should offer:

- Recent workspaces.
- Recent PDFs.
- One Open action whose picker accepts either a workspace folder or a PDF.

A regular workspace window or tab always has a workspace. Cancelling the
picker does not create an empty window.

The workspace home view appears when a tab has a workspace but no selected PDF.
It should offer:

- The current workspace name and path.
- Recently opened PDFs from this workspace.
- Open Different Workspace as a secondary action.

The sidebar remains the place to browse all workspace entries; the home view
does not need a second directory browser.

## Sidebar Requirements

The sidebar is part of the core product, not an optional extra. It should:

- Show the current workspace directory tree.
- Include directories and PDFs.
- Let users lazily expand directories.
- Select PDFs without changing the workspace root.
- Reveal the selected PDF when possible.
- Support opening a PDF in a new tab.
- Support showing a file in Finder.

The app is not a general-purpose file manager. It should not expose broad file
operations such as move, delete, rename, or arbitrary file editing.

## Reader Inspector Requirements

The optional reader inspector complements the PDF without replacing the main
reader. It should provide three views of the selected PDF:

- Page thumbnails that navigate the current reader.
- The PDF table of contents, when one exists.
- Document and current-reader information.

The reader-panel toolbar control mirrors these three sections. Exactly the
visible section is highlighted; when the inspector is collapsed, none is
highlighted. Inspector controls are unavailable when no PDF is selected.

The inspector belongs to each native window or tab, follows that tab's selected
PDF, and remains collapsible like native window-shell state. On supported macOS
versions, the reader should continue beneath native sidebar and inspector
material, matching Preview rather than reserving opaque side columns.

## Reader Requirements

The reader should be Preview-like and PDFKit-powered. It should support:

- Reading PDFs.
- Page navigation.
- Zoom in, zoom out, actual size, and zoom to fit.
- Default to zoom to fit when displaying a PDF.
- Leave fit mode after any manual zoom, including a trackpad pinch, until the
  user chooses Zoom to Fit again.
- Search within the current PDF.
- Highlighting search matches.
- Restoring last reading position per PDF.
- Opening the current PDF in the default app.
- Sharing the current PDF.

Future PDF interactions such as annotations or highlights should be designed as
reader features, not as workspace navigation features.

## Recents And Persistence

The app tracks recent workspaces and recent PDFs separately.

Recent workspaces represent directories the user explicitly opened or that were
inferred from opened PDFs.

Recent PDFs represent files the user opened or selected.

Reading positions are currently persisted per PDF. Broader workspace
restoration is planned: it should restore the workspace root, selected PDF if
any, and expanded folders when practical. That work must respect macOS sandbox
file-access rules and should not be inferred from the existing raw-URL recents
store.

## Non-Goals

- General file management.
- Editing PDF file contents.
- Replacing Finder.
- A custom non-native window chrome.
- A fake-native tab bar.
- Treating one PDF file as the entire app model.

## Product Decisions

- The app is workspace-based.
- Opening a PDF derives a workspace from the PDF's parent directory.
- Opening a folder is a first-class action.
- A workspace may exist without a selected PDF.
- Regular windows and tabs always have a workspace.
- The no-workspace experience is a separate launch panel.
- Native tabs are part of the product.
- Toolbar and sidebar visibility should behave like native window-shell state.
- Search and PDF controls are first-class reader interactions.
