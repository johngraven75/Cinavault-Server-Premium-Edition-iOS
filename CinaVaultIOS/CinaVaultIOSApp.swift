import SwiftUI

private enum RecoveryMonitor {
    private static let activeKey = "cinavault_ios_active_session_marker"

    static func beginLaunch() -> String? {
        let defaults = UserDefaults.standard
        let previousSessionWasActive = defaults.bool(forKey: activeKey)
        defaults.set(true, forKey: activeKey)
        guard previousSessionWasActive else { return nil }
        return "CV-IOS-\(String(Int(Date().timeIntervalSince1970), radix: 16).uppercased())"
    }

    static func markActive() { UserDefaults.standard.set(true, forKey: activeKey) }
    static func markCleanBackground() { UserDefaults.standard.set(false, forKey: activeKey) }
}

@main
struct CinaVaultIOSApp: App {
    @UIApplicationDelegateAdaptor(CinaVaultAppDelegate.self) private var appDelegate
    @StateObject private var model = CinaVaultModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var recoveryDiagnostic: String? = RecoveryMonitor.beginLaunch()

    var body: some Scene {
        WindowGroup {
            Build109RootView(model: model, recoveryDiagnostic: $recoveryDiagnostic)
                .preferredColorScheme(.dark)
                .background(CVColor.ink)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: RecoveryMonitor.markActive()
                    case .background: RecoveryMonitor.markCleanBackground()
                    case .inactive: break
                    @unknown default: break
                    }
                }
        }
    }
}
