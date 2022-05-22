// DELETE ME!

import Cocoa

class Document: NSDocument {

    override class var autosavesInPlace: Bool {
        return true
    }

    override var windowNibName: NSNib.Name? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return NSNib.Name("Document")
    }

    override func read(from url: URL, ofType typeName: String) throws {
        NSLog("rendering \(url) of type: \(typeName)")
    }
}
