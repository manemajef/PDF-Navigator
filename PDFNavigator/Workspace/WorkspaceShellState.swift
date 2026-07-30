/// User-controlled presentation state for one native workspace tab.
/// New tabs copy this value; document changes never mutate it.
struct WorkspaceShellState {
    var isSidebarVisible = false
    var isToolbarVisible = true
}
