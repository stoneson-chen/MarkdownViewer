import Foundation

extension Bundle {
    /// A helper to find the localization bundle, falling back to main if the SPM module bundle isn't available or doesn't contain strings.
    static var appResources: Bundle {
        #if DEBUG
        return Bundle.module
        #else
        // SwiftPM executable resource accessors look beside Bundle.main.bundleURL in packaged apps.
        if let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("MarkdownViewer_MarkdownViewer.bundle")) {
            return bundle
        }
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("MarkdownViewer_MarkdownViewer.bundle"),
           let bundle = Bundle(url: bundleURL) {
            return bundle
        }
        // Fallback to main bundle (where we also copy .lproj files in package_app.sh)
        return Bundle.main
        #endif
    }
}
