import AppKit
import Synchronization

final class WorkspaceDocument: NSDocument {
    private enum RestorationKey {
        static let workspaceRoot = "workspaceRootURL"
        static let selectedPDF = "selectedPDFURL"
    }

    /// The request this document was created or reopened with. Once a window
    /// controller exists its `TabSession` is the authority; this only covers
    /// the gap between `read(from:ofType:)` and `makeWindowControllers()`.
    private nonisolated let pendingRequest = Mutex<OpenRequest?>(nil)

    private var windowController: WindowController? {
        windowControllers.first as? WindowController
    }

    /// What this document would encode or open right now.
    private var currentRequest: OpenRequest? {
        if let session = windowController?.session {
            return OpenRequest(
                workspaceRootURL: session.root,
                selectedPDFURL: session.selection
            )
        }
        return pendingRequest.withLock { $0 }
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
        guard let request = currentRequest else { return }
        let controller = WindowController(request: request)
        addWindowController(controller)
        controller.refreshWindowIdentity()
        (NSApp.delegate as? AppDelegate)?.configure(controller)
    }

    func open(_ request: OpenRequest) {
        // Session first: `apply` sets `fileURL`, and AppKit responds by asking
        // every window controller to resynchronize its title. Doing that while
        // the session still described the previous location is what let the
        // titlebar briefly show the wrong thing.
        windowController?.open(request)
        apply(request)
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        guard let request = currentRequest else { return }
        coder.encode(request.workspaceRootURL, forKey: RestorationKey.workspaceRoot)
        if let selectedPDFURL = request.selectedPDFURL {
            coder.encode(selectedPDFURL, forKey: RestorationKey.selectedPDF)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        guard let rootURL = coder.decodeObject(
            of: NSURL.self,
            forKey: RestorationKey.workspaceRoot
        ) as URL? else { return }

        let pdfURL = coder.decodeObject(
            of: NSURL.self,
            forKey: RestorationKey.selectedPDF
        ) as URL?
        open(pdfURL.map { .pdf($0, in: rootURL) } ?? .folder(rootURL))
    }

    // MARK: - Reading

    override nonisolated func read(from url: URL, ofType typeName: String) throws {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory)
        pendingRequest.withLock {
            $0 = isDirectory.boolValue ? .folder(standardized) : .pdf(standardized)
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

    private func apply(_ request: OpenRequest) {
        pendingRequest.withLock { $0 = request }
        fileURL = request.workspaceRootURL
        invalidateRestorableState()
    }
}
