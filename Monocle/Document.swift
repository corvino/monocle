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

    @IBAction func reloadWebContent(_ sender: Any) {
        Task { @MainActor in
            if let url = fileURL {
                if let y = try? await webView.evaluate(javascript: "window.scrollY") as? Double {
                    // Stash the scroll offset for rescrolling after reload.
                    webScrollY = y
                }
                html = docToHTML(from: url)
            }
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

        let html = {
            if let preambleRange = output.range(of: preamble) {
                return String(output[preambleRange.upperBound...])
            } else {
                return output
            }
        }()

        writeDebugOutput(from: url, html: html)

        return html
    }

    override func read(from url: URL, ofType typeName: String) throws {
        html = docToHTML(from: url)
        if let path = url.filePath {
            watcher = Watcher(path: path) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.reloadWebContent(self)
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

    private func writeDebugOutput(from: URL, html: String) {
        guard let debugDir = FileManager.default.debugDirectory else { return }

        do {
            try FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)
        } catch {
            Swift.print("Error creating debug directory: \(error)")
            return
        }

        // Ensure output extension is .html
        let inputFilename = from.lastPathComponent
        let basename = inputFilename.hasSuffix(".org") ? String(inputFilename.dropLast(4)) : inputFilename
        let outputFilename = basename + ".html"
        let outputPath = debugDir.appendingPathComponent(String(outputFilename))

        do {
            try html.write(to: outputPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            Swift.print("Error writing debug output: \(error)")
        }
    }
}
