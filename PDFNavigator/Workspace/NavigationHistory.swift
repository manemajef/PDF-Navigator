import Foundation

struct NavigationHistory {
    private var entries: [URL] = []
    private var index: Int?

    var canGoBack: Bool {
        guard let index else { return false }
        return index > entries.startIndex
    }

    var canGoForward: Bool {
        guard let index else { return false }
        return index < entries.count - 1
    }

    mutating func reset(to url: URL?) {
        entries = url.map { [$0] } ?? []
        index = entries.isEmpty ? nil : 0
    }

    mutating func visit(_ url: URL) {
        if let index, entries[index] == url { return }

        if let index, index + 1 < entries.count {
            entries.removeSubrange((index + 1)..<entries.count)
        }

        entries.append(url)
        index = entries.count - 1
    }

    mutating func goBack() -> URL? {
        guard let index, canGoBack else { return nil }
        let previousIndex = index - 1
        self.index = previousIndex
        return entries[previousIndex]
    }

    mutating func goForward() -> URL? {
        guard let index, canGoForward else { return nil }
        let nextIndex = index + 1
        self.index = nextIndex
        return entries[nextIndex]
    }
}
