import Foundation

struct NavigationHistory {
    private(set) var entries: [URL] = []
    private(set) var currentIndex: Int?

    var current: URL? {
        guard let currentIndex else {
            return nil
        }

        return entries[currentIndex]
    }

    var canGoBack: Bool {
        guard let currentIndex else {
            return false
        }

        return currentIndex > entries.startIndex
    }

    var canGoForward: Bool {
        guard let currentIndex else {
            return false
        }

        return currentIndex < entries.count - 1
    }

    mutating func reset(to url: URL?) {
        entries = url.map { [$0] } ?? []
        currentIndex = entries.isEmpty ? nil : 0
    }

    mutating func visit(_ url: URL) {
        guard current != url else {
            return
        }

        if let currentIndex {
            let forwardStart = currentIndex + 1

            if forwardStart < entries.count {
                entries.removeSubrange(
                    forwardStart..<entries.count
                )
            }
        }

        entries.append(url)
        currentIndex = entries.count - 1
    }

    mutating func goBack() -> URL? {
        guard let currentIndex, canGoBack else {
            return nil
        }

        self.currentIndex = currentIndex - 1
        return current
    }

    mutating func goForward() -> URL? {
        guard let currentIndex, canGoForward else {
            return nil
        }

        self.currentIndex = currentIndex + 1
        return current
    }
}
