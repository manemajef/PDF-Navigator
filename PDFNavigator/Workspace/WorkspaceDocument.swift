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

    convenience init(request: WorkspaceOpenRequest) {
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
        let controller = WorkspaceWindowController()
        addWindowController(controller)
        (NSApp.delegate as? AppDelegate)?.configure(controller)
        controller.open(openRequest)
    }

    func open(_ request: WorkspaceOpenRequest) {
        apply(request)
        (windowControllers.first as? WorkspaceWindowController)?.open(request)
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

    private nonisolated func apply(_ request: WorkspaceOpenRequest) {
        workspaceRootStorage.withLock { $0 = request.workspaceRootURL }
        selectedPDFStorage.withLock { $0 = request.selectedPDFURL }
    }

    private var openRequest: WorkspaceOpenRequest {
        if let selectedPDFURL {
            return .pdf(selectedPDFURL)
        }
        if let workspaceRootURL {
            return .folder(workspaceRootURL)
        }
        return .empty
    }
}
