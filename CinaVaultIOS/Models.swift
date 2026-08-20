import Foundation

struct RemoteSession: Codable, Equatable {
    let endpoint: URL
    let token: String
    let email: String
    let expiresAt: String
    let permissions: [String]
}

struct MediaItem: Codable, Identifiable, Hashable {
    let mediaKey: String
    let title: String
    let mediaType: String
    let year: Int?
    let rating: Double?
    let overview: String?
    let genre: String?
    let duration: Int64?
    let fileSize: Int64?
    let resolution: String?
    let codec: String?
    let verified: Bool
    let watched: Bool
    let favorite: Bool
    let dateAdded: String
    let lastPlayed: String?
    let tmdbId: String?
    let imdbId: String?
    let artworkUrl: String?
    let streamUrl: String

    var id: String { mediaKey }
}

struct ServerInfo: Codable, Equatable {
    let name: String
    let product: String
    let version: String
    let build: String
    let accountEmail: String
    let permissions: [String]
    let remoteTransport: String
    let mediaIdentifiers: String
    let localPathsExposed: Bool
}

struct ControlMetric: Codable, Hashable {
    let label: String
    let value: String
    let status: String
}

struct ControlAction: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
    let enabled: Bool
    let dangerous: Bool
}

struct ControlSection: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let metrics: [ControlMetric]
    let actions: [ControlAction]
}

struct ControlSnapshot: Codable, Equatable {
    let available: Bool
    let generatedAt: String
    let message: String
    let sections: [String: ControlSection]

    static func unavailable(_ message: String) -> ControlSnapshot {
        ControlSnapshot(
            available: false,
            generatedAt: "",
            message: message,
            sections: [:]
        )
    }

    func section(_ destination: AppDestination) -> ControlSection? {
        sections[destination.parityID]
    }
}

struct CastGrant: Codable, Equatable {
    let streamUrl: String
    let artworkUrl: String?
    let expiresAt: String
}

enum AppDestination: String, CaseIterable, Identifiable, Codable {
    case library
    case sources
    case downloads
    case liveTV = "live-tv"
    case server
    case security
    case remote
    case advanced
    case cloudNAS = "cloud-nas"
    case extensions
    case intelligence = "ai-autopilot"
    case settings
    case casting
    case player

    var id: String { rawValue }
    var parityID: String { rawValue }

    static let primary: [AppDestination] = [
        .library,
        .sources,
        .downloads,
        .liveTV,
        .server,
        .security,
        .remote,
        .advanced,
        .cloudNAS,
        .extensions,
        .intelligence,
        .settings,
    ]

    static let compact: [AppDestination] = [
        .library,
        .sources,
        .remote,
        .intelligence,
        .settings,
    ]

    var label: String {
        switch self {
        case .library: "Library"
        case .sources: "Media Sources"
        case .downloads: "Downloads"
        case .liveTV: "Live TV"
        case .server: "Server Core"
        case .security: "Security"
        case .remote: "Remote Access"
        case .advanced: "Advanced"
        case .cloudNAS: "Cloud & NAS"
        case .extensions: "Extensions"
        case .intelligence: "AI Autopilot"
        case .settings: "Settings"
        case .casting: "Casting"
        case .player: "Now Playing"
        }
    }

    var shortLabel: String {
        switch self {
        case .library: "Vault"
        case .sources: "Sources"
        case .downloads: "Queue"
        case .liveTV: "Live"
        case .server: "Server"
        case .security: "Guard"
        case .remote: "Remote"
        case .advanced: "Tools"
        case .cloudNAS: "Cloud"
        case .extensions: "Extend"
        case .intelligence: "AI"
        case .settings: "Setup"
        case .casting: "Cast"
        case .player: "Play"
        }
    }

    var eyebrow: String {
        switch self {
        case .library: "CINEMATIC LIBRARY"
        case .sources: "AUTONOMOUS INGESTION"
        case .downloads: "ACQUISITION STREAM"
        case .liveTV: "BROADCAST FABRIC"
        case .server: "EMBEDDED MEDIA CORE"
        case .security: "TRUSTED COMPUTE"
        case .remote: "ANYWHERE ACCESS"
        case .advanced: "EXPERT SYSTEMS"
        case .cloudNAS: "STORAGE FABRIC"
        case .extensions: "CAPABILITY LAYER"
        case .intelligence: "AUTONOMOUS INTELLIGENCE"
        case .settings: "EXPERIENCE DESIGN"
        case .casting: "DEVICE ORBIT"
        case .player: "SECURE PLAYBACK"
        }
    }

    var stageTitle: String {
        switch self {
        case .library: "The Vault"
        case .sources: "Source Constellation"
        case .downloads: "Incoming Media"
        case .liveTV: "Live Signal"
        case .server: "Server Nexus"
        case .security: "Security Matrix"
        case .remote: "Remote Orbit"
        case .advanced: "Control Lab"
        case .cloudNAS: "Cloud Mesh"
        case .extensions: "Extension Forge"
        case .intelligence: "AI Autopilot"
        case .settings: "Personalize CinaVault"
        case .casting: "Casting Center"
        case .player: "Now Playing"
        }
    }

    var symbol: String {
        switch self {
        case .library: "square.grid.3x3.fill"
        case .sources: "folder.fill"
        case .downloads: "arrow.down.circle.fill"
        case .liveTV: "tv.fill"
        case .server: "server.rack"
        case .security: "lock.shield.fill"
        case .remote: "network"
        case .advanced: "slider.horizontal.3"
        case .cloudNAS: "externaldrive.connected.to.line.below.fill"
        case .extensions: "puzzlepiece.extension.fill"
        case .intelligence: "sparkles"
        case .settings: "gearshape.fill"
        case .casting: "airplayvideo"
        case .player: "play.circle.fill"
        }
    }
}
