import AppKit
import Synchronization

final class WorkspaceDocument: NSDocument {
    private nonisolated let workspaceRootStorage = Mutex<URL?>(nil)
    private nonisolated let selectedPDFStorage = Mutex<URL?>(nil)

    var workspaceRootURL: URL? {
        workspaceRootStorage.withLock { $0 }
    }

    var selectedPDFURL: URL? {
        selectedPDFStorage.withLock { $0 }
    }

    convenience init(request: OpenRequest) {
        self.init()
        apply(request)
    }

    override init() {
        super.init()
        hasUndoManager = false
    }

    override nonisolated class var autosavesInPlace: Bool {
        false
    }

    override var isDocumentEdited: Bool {
        false
    }

    override func makeWindowControllers() {
        guard let request = openRequest else { return }
        let controller = WindowController(request: request)
        addWindowController(controller)
        controller.refreshWindowIdentity()
        (NSApp.delegate as? AppDelegate)?.configure(controller)
    }

    func open(_ request: OpenRequest) {
        apply(request)
        invalidateRestorableState()
        (windowControllers.first as? WindowController)?.open(request)
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let workspaceRootURL {
            coder.encode(workspaceRootURL, forKey: "workspaceRootURL")
        }
        if let selectedPDFURL {
            coder.encode(selectedPDFURL, forKey: "selectedPDFURL")
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        let rootURL = coder.decodeObject(of: NSURL.self, forKey: "workspaceRootURL") as URL?
        let pdfURL = coder.decodeObject(of: NSURL.self, forKey: "selectedPDFURL") as URL?
        if let rootURL {
            let request: OpenRequest = pdfURL.map { .pdf($0, in: rootURL) } ?? .folder(rootURL)
            apply(request)
            (windowControllers.first as? WindowController)?.open(request)
        }
    }

    override nonisolated func read(from url: URL, ofType typeName: String) throws {
        let standardized = url.standardizedFileURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDir), isDir.boolValue {
            apply(.folder(standardized))
        } else {
            apply(.pdf(standardized))
        }
    }

    override nonisolated func data(ofType typeName: String) throws -> Data {
        throw CocoaError(.fileWriteNoPermission)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(save(_:)),
             #selector(saveAs(_:)),
             #selector(saveTo(_:)),
             #selector(revertToSaved(_:)):
            return false
        default:
            return super.validateUserInterfaceItem(item)
        }
    }

    private nonisolated func apply(_ request: OpenRequest) {
        workspaceRootStorage.withLock { $0 = request.workspaceRootURL }
        selectedPDFStorage.withLock { $0 = request.selectedPDFURL }
        Task { @MainActor in
            self.fileURL = request.workspaceRootURL
        }
    }
    private var openRequest: OpenRequest? {
        guard let workspaceRootURL else { return nil }

        if let selectedPDFURL {
            return .pdf(selectedPDFURL, in: workspaceRootURL)
        }

        return .folder(workspaceRootURL)
    }

}
