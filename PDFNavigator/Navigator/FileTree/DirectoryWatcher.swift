import CoreServices
import Foundation

/// Reports that something changed somewhere under a root directory.
///
/// One FSEvents stream covers the entire subtree, so the navigator never has to
/// add or drop watches as folders expand and collapse — which is the bookkeeping
/// that makes a per-directory `DispatchSource` approach fiddly. The system also
/// coalesces bursts for us, so a copy of two hundred files arrives as a handful
/// of callbacks rather than two hundred.
///
/// The callback deliberately carries no payload. FSEvents can report
/// `MustScanSubDirs` when its queue overflows, so any consumer has to be able to
/// rescan from scratch anyway; `FileTree` rescans only the directories it
/// has actually loaded, which is bounded by what the user has expanded.
final class DirectoryWatcher {
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    /// Long enough for the system to coalesce a burst, short enough that a file
    /// saved into the workspace shows up while the user is still looking.
    private static let latency: CFTimeInterval = 0.2

    init(root: URL, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        start(root: root)
    }

    deinit {
        stop()
    }

    private func start(root: URL) {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // An FSEvents callback is a C function pointer and cannot capture, so
        // the watcher travels through `context.info` as an unretained pointer.
        // That is safe only because `stop()` runs in `deinit` on the same queue
        // the callbacks are dispatched to, so no callback can be in flight once
        // the stream is invalidated.
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>
                .fromOpaque(info)
                .takeUnretainedValue()
            MainActor.assumeIsolated(watcher.onChange)
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot
            )
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
