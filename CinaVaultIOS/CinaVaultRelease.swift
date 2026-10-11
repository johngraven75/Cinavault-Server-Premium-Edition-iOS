import Foundation

/// The CinaVault Premium release this build matches. The Windows app sets the
/// numbering; scripts/verify_project.py keeps this in step with project.yml.
enum CinaVaultRelease {
    static let displayName = "v1.0.3 Pre-Beta Build 103"

    /// Marketing version and build number from the app bundle, e.g. "1.0.3 (1003)".
    static var bundleVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
