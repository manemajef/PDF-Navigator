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
        (windowControllers.first as? WindowController)?.open(request)
    }

    override nonisolated func read(from url: URL, ofType typeName: String) throws {
        apply(.pdf(url))
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
    }

    private var openRequest: OpenRequest? {
        if let selectedPDFURL {
            return .pdf(selectedPDFURL)
        }
        if let workspaceRootURL {
            return .folder(workspaceRootURL)
        }
        return nil
    }
}
