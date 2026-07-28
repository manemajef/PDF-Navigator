import Foundation

struct ReadingPosition: Codable, Sendable {
    let pageIndex: Int
    let pointX: Double
    let pointY: Double
    let scaleFactor: Double
}

struct ReadingPositionStore {
    private let defaults: UserDefaults
    private let storageKey =
        "readingPositionsByDocumentURL"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func position(for url: URL) -> ReadingPosition? {
        positions[url.standardizedFileURL.absoluteString]
    }

    func save(
        _ position: ReadingPosition,
        for url: URL
    ) {
        var positions = positions
        positions[url.standardizedFileURL.absoluteString] =
            position

        guard let data = try? JSONEncoder().encode(
            positions
        ) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private var positions: [String: ReadingPosition] {
        guard
            let data = defaults.data(forKey: storageKey),
            let positions = try? JSONDecoder().decode(
                [String: ReadingPosition].self,
                from: data
            )
        else {
            return [:]
        }

        return positions
    }
}
