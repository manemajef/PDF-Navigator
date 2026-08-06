import Foundation

/// Back and forward workspace locations for one tab session.
struct NavigationHistory {
    private var entries: [OpenRequest] = []
    private var index: Int?

    var canGoBack: Bool {
        guard let index else { return false }
        return index > entries.startIndex
    }

    var canGoForward: Bool {
        guard let index else { return false }
        return index < entries.count - 1
    }

    mutating func reset(to request: OpenRequest) {
        entries = [request]
        index = 0
    }

    mutating func visit(_ request: OpenRequest) {
        if let index, entries[index] == request { return }

        if let index, index + 1 < entries.count {
            entries.removeSubrange((index + 1)..<entries.count)
        }

        entries.append(request)
        index = entries.count - 1
    }

    mutating func goBack() -> OpenRequest? {
        guard let index, canGoBack else { return nil }
        let previousIndex = index - 1
        self.index = previousIndex
        return entries[previousIndex]
    }

    mutating func goForward() -> OpenRequest? {
        guard let index, canGoForward else { return nil }
        let nextIndex = index + 1
        self.index = nextIndex
        return entries[nextIndex]
    }
}
