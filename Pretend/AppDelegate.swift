import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            do {
                let url =  URL(fileURLWithPath: filename)

                if let document = NSDocumentController.shared.document(for: url) {
                    document.showWindows()
                } else {
                    let document = try Document(contentsOf: url, ofType: "org")
                    NSDocumentController.shared.addDocument(document)
                    document.makeWindowControllers()
                    document.showWindows()
                }
            } catch {
                print("Error opening Org mode document.")
                print(error)
            }
        }
    }
}
