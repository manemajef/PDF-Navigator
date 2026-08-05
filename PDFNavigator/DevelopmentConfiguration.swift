import Foundation

#if DEBUG
enum DevelopmentConfiguration {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let demoDirURL = repositoryRoot
        .appendingPathComponent("DEMO_DIR", isDirectory: true)

    static let demoPDFURL = demoDirURL
        .appendingPathComponent("micro3-sylabus.pdf", isDirectory: false)

    static let demoOutlinePDFURL = demoDirURL
        .appendingPathComponent("lecs/micro3-lec-8b.pdf", isDirectory: false)
}
#endif
