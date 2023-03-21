import Foundation

class Watcher {
    private let eventSource: DispatchSourceFileSystemObject

    init?(path: String, handler: @escaping () -> Void) {
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let desc = open(path, O_EVTONLY)
        guard -1 != desc else { return nil }

        eventSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: desc, eventMask: .write)
        eventSource.setEventHandler(handler: handler)

        eventSource.setCancelHandler {
            close(desc)
        }

        eventSource.resume()
    }
}
