import AppKit
import Foundation

@MainActor
final class WindowStateStore {
    static let shared = WindowStateStore()

    private let defaults = UserDefaults.standard
    private let windowStatesKey = "savedWindowStates"

    struct WindowState: Codable, Equatable {
        struct TabState: Codable, Equatable {
            var workspaceRootURL: URL
            var selectedPDFURL: URL?
        }

        var tabs: [TabState]
        var selectedTabIndex: Int
        var frameString: String?
    }

    private init() {}

    var shouldRestoreWindows: Bool {
        if defaults.bool(forKey: "ApplePersistenceIgnoreState") {
            return false
        }
        if let value = defaults.object(forKey: "NSQuitAlwaysKeepsWindows") as? Bool {
            return value
        }
        if let number = defaults.object(forKey: "NSQuitAlwaysKeepsWindows") as? NSNumber {
            return number.boolValue
        }
        return true
    }

    var savedWindowStates: [WindowState] {
        get {
            guard let data = defaults.data(forKey: windowStatesKey) else { return [] }
            return (try? JSONDecoder().decode([WindowState].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: windowStatesKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: windowStatesKey)
            }
        }
    }

    func clearSavedWindows() {
        defaults.removeObject(forKey: windowStatesKey)
    }

    func saveCurrentWindows(from windows: [NSWindow]) {
        var processedTabGroups = Set<NSWindowTabGroup>()
        var processedWindows = Set<NSWindow>()
        var states: [WindowState] = []

        for window in windows {
            guard window.windowController is WindowController else {
                continue
            }

            if let tabGroup = window.tabGroup {
                if processedTabGroups.contains(tabGroup) {
                    continue
                }
                processedTabGroups.insert(tabGroup)

                let tabWindows = tabGroup.windows.compactMap {
                    $0.windowController is WindowController ? $0 : nil
                }
                guard !tabWindows.isEmpty else { continue }

                var tabs: [WindowState.TabState] = []
                for tabWindow in tabWindows {
                    guard let controller = tabWindow.windowController as? WindowController else { continue }
                    tabs.append(WindowState.TabState(
                        workspaceRootURL: controller.session.root,
                        selectedPDFURL: controller.session.selection
                    ))
                    processedWindows.insert(tabWindow)
                }

                guard !tabs.isEmpty else { continue }

                let selectedIndex: Int
                if let selectedWindow = tabGroup.selectedWindow,
                   let index = tabWindows.firstIndex(of: selectedWindow) {
                    selectedIndex = index
                } else {
                    selectedIndex = 0
                }

                let activeWindow = tabGroup.selectedWindow ?? tabWindows.first
                let frameString = activeWindow?.frameDescriptor

                states.append(WindowState(
                    tabs: tabs,
                    selectedTabIndex: selectedIndex,
                    frameString: frameString
                ))
            } else {
                if processedWindows.contains(window) {
                    continue
                }
                processedWindows.insert(window)

                guard let controller = window.windowController as? WindowController else { continue }
                let tabState = WindowState.TabState(
                    workspaceRootURL: controller.session.root,
                    selectedPDFURL: controller.session.selection
                )
                states.append(WindowState(
                    tabs: [tabState],
                    selectedTabIndex: 0,
                    frameString: window.frameDescriptor
                ))
            }
        }

        savedWindowStates = states
    }

    func restoreWindows(
        using openTab: (OpenRequest, NSWindow?, TabActivation) -> WindowController?
    ) -> Bool {
        let states = savedWindowStates
        guard !states.isEmpty else { return false }

        var restoredAny = false

        for state in states {
            let validTabs = state.tabs.filter { tab in
                FileManager.default.fileExists(atPath: tab.workspaceRootURL.path)
            }
            guard let firstTab = validTabs.first else { continue }

            let firstPDFURL = firstTab.selectedPDFURL.flatMap {
                FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
            }
            let firstRequest = OpenRequest(
                workspaceRootURL: firstTab.workspaceRootURL,
                selectedPDFURL: firstPDFURL
            )

            guard let firstController = openTab(firstRequest, nil, .foreground),
                  let firstWindow = firstController.window else {
                continue
            }

            restoredAny = true

            for tab in validTabs.dropFirst() {
                let pdfURL = tab.selectedPDFURL.flatMap {
                    FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
                }
                let request = OpenRequest(
                    workspaceRootURL: tab.workspaceRootURL,
                    selectedPDFURL: pdfURL
                )
                _ = openTab(request, firstWindow, .background)
            }

            if let tabGroup = firstWindow.tabGroup {
                let tabWindows = tabGroup.windows
                if state.selectedTabIndex >= 0 && state.selectedTabIndex < tabWindows.count {
                    let selectedWindow = tabWindows[state.selectedTabIndex]
                    tabGroup.selectedWindow = selectedWindow
                    selectedWindow.makeKeyAndOrderFront(nil)
                }
            }

            if let frameString = state.frameString {
                let targetWindow = firstWindow.tabGroup?.selectedWindow ?? firstWindow
                targetWindow.setFrame(from: frameString)
            }
        }

        return restoredAny
    }
}
