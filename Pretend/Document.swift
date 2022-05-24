// DELETE ME!

import Cocoa
import WebKit

extension URL {
    var filePath: String? {
        guard self.isFileURL else { return nil }
        return self.path
    }
}

class Document: NSDocument {

    var watcher: Watcher?

    @IBOutlet weak var webView: WKWebView! {
        didSet {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    var html: String = "" {
        didSet {
            if let webView = webView {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override var windowNibName: NSNib.Name? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return NSNib.Name("Document")
    }

    @IBAction func reloadWebContent(_ sender: Any) {
        if let url = fileURL {
            html = docToHTML(from: url)
        }
    }

    func docToHTML(from url: URL) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe

        let input = url.filePath!
        let elFile = Bundle.main.bundlePath + "/Contents/Resources/org-html.el"
         task.arguments = [input, "-l", elFile, "--batch", "--eval", "(org-to-html)"]
         task.executableURL = URL(fileURLWithPath: "/usr/local/bin/emacs")

        task.standardInput = nil
        do {
            try task.run()
        } catch {
            Swift.print(error)
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)!
    }

    override func read(from url: URL, ofType typeName: String) throws {
        html = docToHTML(from: url)
        if let path = url.filePath {
            watcher = Watcher(path: path) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.html = self.docToHTML(from: url)
                }
            }
        }
    }
}

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
