import SwiftUI

/// How far a Windows CinaVault Premium beta-3 capability has actually
/// travelled to this iOS remote client. This table is documentation with
/// teeth: it is rendered in Settings and guarded by ParityTests, so a
/// future change cannot silently re-label a gap as a duplicate.
///
/// - carriedViaServer: the iOS client uses it today through the
///   authenticated Windows server API (the feature itself runs on Windows).
/// - clientScaffold: the iOS surface exists (a destination, a theme, a
///   placeholder state) but the Windows beta-3 server does not expose the
///   backing endpoint, so it is not a live capability.
/// - leftBehind: the Windows capability has no iOS equivalent yet. Under
///   the platform-set green rule this must stay explicitly listed until
///   it is ported or the owner specifically exempts it.
enum Beta3PortStatus: String {
    case carriedViaServer
    case clientScaffold
    case leftBehind

    var label: String {
        switch self {
        case .carriedViaServer: "Carried via server"
        case .clientScaffold: "Scaffold only"
        case .leftBehind: "Left behind"
        }
    }
}

struct Beta3PortEntry: Identifiable {
    let id: String
    let area: String
    let windowsFeature: String
    let status: Beta3PortStatus
    let note: String
}

enum PlatformParity {
    /// The Windows release this table audits. Kept identical to
    /// CinaVaultRelease.displayName so the two cannot drift apart.
    static let windowsDisplayName = CinaVaultRelease.displayName

    static let entries: [Beta3PortEntry] = [
        Beta3PortEntry(
            id: "library",
            area: "Library",
            windowsFeature: "Unified library across drives, NAS and cloud, with authenticated artwork and metadata refresh",
            status: .carriedViaServer,
            note: "iOS browses the server library over HTTPS with opaque media keys and refreshes artwork and metadata on refresh. Local scanning itself stays on Windows."
        ),
        Beta3PortEntry(
            id: "player",
            area: "Player",
            windowsFeature: "Direct play plus on-the-fly transcoding, resume, skip intro/credits, Next Up, gapless",
            status: .leftBehind,
            note: "iOS plays only the granted stream directly with AVPlayer. Transcoding, resume, skip intro/credits and Next Up are not ported."
        ),
        Beta3PortEntry(
            id: "metadata-actions",
            area: "Metadata (3-dot actions)",
            windowsFeature: "Per-card Check metadata, Unmatch and Delete, re-fetching through every enabled adult provider",
            status: .leftBehind,
            note: "No per-card action exists on iOS and the Windows server exposes no remote endpoint for it. iOS shows only server-reported provider readiness."
        ),
        Beta3PortEntry(
            id: "vault",
            area: "Vault encryption",
            windowsFeature: "Passphrase-gated vault: XChaCha20-Poly1305, Argon2id, sealed database and artwork, startup gate",
            status: .leftBehind,
            note: "Windows vault commands are Tauri IPC only, with no remote vault endpoint. The iOS session is stored in Apple Keychain; that is session storage, not the Windows vault, and must never be presented as the vault."
        ),
        Beta3PortEntry(
            id: "wireguard",
            area: "WireGuard VPN",
            windowsFeature: "WireGuard engine readiness, verified profile import, tunnel control and startup auto-connect",
            status: .leftBehind,
            note: "The iOS Security tab only links to iOS Settings. A signed Network Extension entitlement and provider configuration are required before the app can create or control a tunnel directly."
        ),
        Beta3PortEntry(
            id: "google-drive",
            area: "Google Drive",
            windowsFeature: "Google Drive OAuth sign-in plus Drive listing and ingestion as a media source",
            status: .leftBehind,
            note: "No Drive UI or OAuth flow exists on iOS, and the Windows beta-3 Drive work itself still needs a real Google OAuth client ID. Nothing here is faked with a placeholder client ID."
        ),
        Beta3PortEntry(
            id: "adult-gating",
            area: "Adult-provider gating / store-safe",
            windowsFeature: "Full-edition adult provider chain enabled by default; separate store-safe edition refuses adult sources and providers",
            status: .leftBehind,
            note: "iOS has adult-provider registry resources but no client gating or store-safe filter. Any gating for phone clients lives server-side only today."
        ),
        Beta3PortEntry(
            id: "themes",
            area: "UI look / themes",
            windowsFeature: "Spatial dark design plus selectable skins in Settings",
            status: .clientScaffold,
            note: "iOS renders one fixed spatial dark theme with the same accent set (cyan, orchid, magenta, emerald, solar). There is no theme picker and no skin selection."
        ),
        Beta3PortEntry(
            id: "server-controls",
            area: "Server core / control destinations",
            windowsFeature: "Sources, downloads, Live TV, server, security, remote, advanced, cloud/NAS and extensions as working panels",
            status: .clientScaffold,
            note: "Destinations exist and render the authenticated server control snapshot when present, but the Windows beta-3 server exposes no /api/control/snapshot endpoint, so they show CONTROL ENDPOINT PENDING instead of live controls."
        ),
        Beta3PortEntry(
            id: "agent-casting",
            area: "Agent and casting",
            windowsFeature: "Holographic agent chat and face, AirPlay and Google Cast with temporary grants",
            status: .carriedViaServer,
            note: "Agent chat and face and AirPlay/Google Cast grants work through the server API. From the phone the agent can look things up but cannot change anything, matching the Windows server's phone limits."
        ),
    ]
}

struct PlatformParityView: View {
    var body: some View {
        Form {
            Section("Windows reference") {
                LabeledContent("Pairs to", value: PlatformParity.windowsDisplayName)
                LabeledContent("iOS bundle", value: "1.0.3 (1003) simulator-only")
                Text("Platform-set green rule: nothing counts as green until ALL OS versions are greenlit — checked and passing workflow all the way through publish and release, on every platform. This platform being green alone does not make the set green.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Beta-3 port status") {
                ForEach(PlatformParity.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.area).font(.headline)
                            Spacer()
                            Text(entry.status.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(entry.status == .leftBehind ? Color.red : entry.status == .clientScaffold ? Color.yellow : Color.green)
                        }
                        Text(entry.windowsFeature).font(.caption).foregroundStyle(.secondary)
                        Text(entry.note).font(.caption)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Platform parity")
    }
}
