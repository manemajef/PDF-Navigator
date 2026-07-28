import Foundation

struct ReadingPosition: Codable {
    let pageIndex: Int
    let pointX: Double
    let pointY: Double
    let zoom: Double
}

struct ReadingPositionStore {
    private let defaults = UserDefaults.standard
    private let key = "readingPositionsByDocumentURL"

    func position(for url: URL) -> ReadingPosition? {
        positions[url.standardizedFileURL.absoluteString]
    }

    func save(_ position: ReadingPosition, for url: URL) {
        var positions = positions
        positions[url.standardizedFileURL.absoluteString] = position
        if let data = try? JSONEncoder().encode(positions) {
            defaults.set(data, forKey: key)
        }
    }

    private var positions: [String: ReadingPosition] {
        guard let data = defaults.data(forKey: key),
              let positions = try? JSONDecoder().decode(
                [String: ReadingPosition].self,
                from: data
              ) else {
            return [:]
        }
        return positions
    }
}
