// DELETE ME!

import Cocoa

extension URL {
    var filePath: String? {
        guard self.isFileURL else { return nil }
        return self.path
    }
}

class Document: NSDocument {

    @IBOutlet var textView: NSTextView! {
        didSet {
            textView.string = message
        }
    }
    var message: String = ""

    override class var autosavesInPlace: Bool {
        return true
    }

    override var windowNibName: NSNib.Name? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return NSNib.Name("Document")
    }

    override func read(from url: URL, ofType typeName: String) throws {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe

        let input = url.filePath!
        let elFile = Bundle.main.bundlePath + "/Contents/Resources/org-html.el"
         task.arguments = ["-l", elFile, "--batch", "--eval", "(org-to-html)", input]
         task.executableURL = URL(fileURLWithPath: "/usr/local/bin/emacs")

        task.standardInput = nil
        do {
            try task.run()
        } catch {
            Swift.print(error)
            message = error.localizedDescription
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

        Swift.print("rendering \(url) of type: \(typeName)")
        Swift.print(output)
        message = "\(output)"
    }
}
