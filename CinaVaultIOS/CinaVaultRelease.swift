import Foundation

/// The CinaVault Premium Windows release this build pairs to. The Windows
/// app sets the numbering; scripts/verify_project.py keeps this in step
/// with docs/platform-parity.json.
///
/// Pairing history: this was "v1.0.3 Pre-Beta Build 103". It now pairs to
/// Windows v2.1.7-beta-3 (main commit 7bd0b75c). The display name follows
/// the release tag; the in-code Windows build-version.json at that commit
/// still reads "Beta 1" with display build 217 (a label mismatch flagged
/// upstream), so "Build 217" here is the build number at that commit, not
/// a claim that the Windows in-code cycle label says Beta 3.
///
/// This is NOT the iOS bundle identity: the iOS app itself remains
/// 1.0.3 (1003) in project.yml, a simulator-only unsigned test build.
/// Only the Windows reference it pairs to moves.
enum CinaVaultRelease {
    static let displayName = "v2.1.7 Beta 3 Build 217"

    /// Marketing version and build number from the app bundle, e.g. "1.0.3 (1003)".
    static var bundleVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
