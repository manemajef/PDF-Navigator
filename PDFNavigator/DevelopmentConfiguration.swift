import Foundation

#if DEBUG
enum DevelopmentConfiguration {
    static let showsInspectorSidebarDemo = true

    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let demoDirURL = repositoryRoot
        .appendingPathComponent("DEMO_DIR", isDirectory: true)

    static let demoPDFURL = demoDirURL
        .appendingPathComponent("micro3-sylabus.pdf", isDirectory: false)
}
#endif
