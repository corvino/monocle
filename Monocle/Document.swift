import Cocoa
import WebKit

extension URL {
    var filePath: String? {
        guard self.isFileURL else { return nil }
        return self.path
    }
}

class Document: NSDocument, WKNavigationDelegate {

    var watcher: Watcher?

    @IBOutlet var sourceWindow: NSWindow!
    @IBOutlet var sourceTextView: NSTextView!

    let webBaseURL = URL(fileURLWithPath: "/")
    @IBOutlet weak var webView: WKWebView! {
        didSet {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
            webView.loadHTMLString(html, baseURL: webBaseURL)
        }
    }
    var webScrollY: Double = 0

    var html: String = "" {
        didSet {
            if let webView = webView {
                webView.loadHTMLString(html, baseURL: webBaseURL)
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

    @IBAction func reloadWebContent(_ sender: Any) async {
        if let url = fileURL {
            if let y = try? await webView.evaluate(javascript: "window.scrollY") as? Double {
                // Stash the scroll offset for rescrolling after reload.
                webScrollY = y
            }
            html = docToHTML(from: url)
        }
    }

    func docToHTML(from url: URL) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe

        let input = url.filePath!
        let resources = Bundle.main.bundlePath + "/Contents/Resources"
        let elFile = resources + "/org-html.el"

        let resourcesURL = Bundle.main.bundleURL.absoluteString + "Contents/Resources"
        task.arguments = [input, "-l", elFile, "--batch", "--eval", "(org-to-html \"\(resourcesURL)\")"]
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/emacs")

        task.standardInput = nil
        do {
            try task.run()
        } catch {
            Swift.print(error)
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        let preamble = "<!-- org-html-export-as-html --!>\n"

        if let preambleRange = output.range(of: preamble) {
            return String(output[preambleRange.upperBound...])
        } else {
            return output
        }
    }

    override func read(from url: URL, ofType typeName: String) throws {
        html = docToHTML(from: url)
        if let path = url.filePath {
            watcher = Watcher(path: path) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    Task { await self.reloadWebContent(self) }
                }
            }
        }
    }

    @IBAction func showPageSource(_ sender: Any) {
        sourceWindow.title = "\(fileURL?.filePath ?? "") HTML Source"
        sourceTextView.string = html
        sourceWindow.setIsVisible(true)
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        DispatchQueue.main.async {
            Task {
                // Scroll back to previous offset.
                _ = try? await webView.evaluate(javascript: "window.scroll(0, \(self.webScrollY))")
                self.webScrollY = 0
            }
        }
    }
}

extension WKWebView {
    func evaluate(javascript: String) async throws -> Any? {
        try await withCheckedThrowingContinuation({ continuation in
            evaluateJavaScript(javascript) { result, error in

                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        })
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
