# PDF Navigator Product Requirements

This document is the source of truth for product intent. It describes what the
app is for, how users expect it to behave, and which decisions define the
product. Technical implementation details belong in `architecture.md`.

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

As a user, I want back and forward navigation to switch between PDFs I recently
visited in the current workspace tab.

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
| PDF navigation history | Back/forward history between selected PDFs in one tab. |
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

Sidebar contents, selected PDF, expanded folders, search state, and PDF history
belong to the active workspace tab.

## Launch Panel And Workspace Home

When the app launches without an open workspace, a separate launch panel
appears. It should offer:

- Recent workspaces.
- Recent PDFs.
- Open Workspace.
- Open PDF.

A regular workspace window or tab always has a workspace. Cancelling the
picker does not create an empty window.

The workspace home view appears when a tab has a workspace but no selected PDF.
It should offer:

- The current workspace name and path.
- Recently opened PDFs from this workspace.
- Useful top-level workspace entries.
- Open Different Workspace as a secondary action.

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

## Reader Requirements

The reader should be Preview-like and PDFKit-powered. It should support:

- Reading PDFs.
- Page navigation.
- Zoom in, zoom out, actual size, and zoom to fit.
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

Restoring a workspace should restore the workspace root, selected PDF if any,
expanded folders when practical, and reading positions. Restoration must respect
macOS sandbox file-access rules.

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
