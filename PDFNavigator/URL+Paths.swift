import Foundation

/// Path questions asked by more then one feature.
/// `nonisolated` because `WorkspaceDocuement.read(from:ofType:)` is nonisolated

nonisolated extension URL {
    func isDescendantOrSame(of other: URL) -> Bool {
        standardizedFileURL.pathComponents
            .starts(with: other.standardizedFileURL.pathComponents)
        
    }
    
    var isExistingDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
