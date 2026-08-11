import AppKit
import Synchronization

final class WorkspaceDocument: NSDocument {
    /// Warning: these are persisted keys. Renaming one discards saved state.
    ///
    /// A selected PDF means reading; otherwise Start Page or the optional
    /// library folder identifies the current location. Older state without
    /// either restores the root.
    private enum RestorationKey {
        static let workspaceRoot = "workspaceRootURL"
        static let selectedPDF = "selectedPDFURL"
        static let libraryFolder = "libraryFolderURL"
        static let startPage = "startPage"
    }

    /// The request this document was created or reopened with. Once a window
    /// controller exists its `WorkspaceSession` is the authority; this only covers
    /// the gap between `read(from:ofType:)` and `makeWindowControllers()`.
    private nonisolated let pendingRequest = Mutex<OpenRequest?>(nil)

    private var windowController: WindowController? {
        windowControllers.first as? WindowController
    }

    /// What this document would encode or open right now.
    private var currentRequest: OpenRequest? {
        if let session = windowController?.session {
            return session.currentRequest
        }
        return pendingRequest.withLock { $0 }
    }

    convenience init(request: OpenRequest) {
        self.init()
        store(request)
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
        store(request)
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        guard let request = currentRequest else { return }
        coder.encode(request.workspaceRootURL, forKey: RestorationKey.workspaceRoot)
        switch request.mode {
        case .startPage:
            coder.encode(true, forKey: RestorationKey.startPage)
        case .reading(let pdfURL):
            coder.encode(pdfURL, forKey: RestorationKey.selectedPDF)
        case .library(let folderURL):
            coder.encode(folderURL, forKey: RestorationKey.libraryFolder)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        guard let rootURL = coder.decodeObject(
            of: NSURL.self,
            forKey: RestorationKey.workspaceRoot
        ) as URL? else { return }

        if let pdfURL = coder.decodeObject(
            of: NSURL.self,
            forKey: RestorationKey.selectedPDF
        ) as URL? {
            open(.pdf(pdfURL, in: rootURL))
        } else if coder.decodeBool(forKey: RestorationKey.startPage) {
            open(.startPage(in: rootURL))
        } else if let folderURL = coder.decodeObject(
            of: NSURL.self,
            forKey: RestorationKey.libraryFolder
        ) as URL? {
            open(.folder(folderURL, in: rootURL))
        } else {
            open(.folder(rootURL, in: rootURL))
        }
    }

    // MARK: - Reading

    override nonisolated func read(from url: URL, ofType typeName: String) throws {
        let standardized = url.standardizedFileURL
        pendingRequest.withLock {
            $0 = standardized.isExistingDirectory ? .folder(standardized) : .pdf(standardized)
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

    private func store(_ request: OpenRequest) {
        pendingRequest.withLock { $0 = request }
        fileURL = request.workspaceRootURL
        invalidateRestorableState()
    }
}
