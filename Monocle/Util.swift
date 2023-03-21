import Foundation
import WebKit

extension FileManager {
    var appSupportDirectory: URL? {
        guard let appSupport = urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }

        return appSupport.appendingPathComponent(bundleIdentifier)
    }

    var debugDirectory: URL? {
        return appSupportDirectory?.appendingPathComponent("debug")
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
