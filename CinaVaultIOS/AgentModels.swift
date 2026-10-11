import Foundation

/// What the server says about its agent (GET /api/agent/status).
struct AgentStatus: Decodable, Equatable {
    let enabled: Bool
    let configured: Bool
    let hasFace: Bool
    let messagesPerHour: Int
}

/// The owner's agent face: a JPEG photo plus its eye and mouth markers.
struct AgentFace: Equatable {
    let photo: Data
    let calibration: PortraitCalibration
}

struct AgentChatMessage: Identifiable, Equatable {
    let id = UUID()
    let fromAgent: Bool
    let text: String
}

struct AgentState: Equatable {
    var status: AgentStatus?
    var face: AgentFace?
    var messages: [AgentChatMessage] = []
    var sending = false
    var error: String?
    /// Until when the head animates the newest reply.
    var speakingUntil: Date = .distantPast

    /// Why the agent can't be used right now, or nil when it can.
    var unavailableReason: String? {
        guard let status else { return "Connecting to the agent…" }
        if !status.enabled { return "The agent is turned off for phones on this server." }
        if !status.configured {
            return "The agent isn't set up yet. Add an Anthropic API key in CinaVault on your computer."
        }
        return nil
    }

    func mood(at date: Date, drafting: Bool) -> AgentMood {
        if sending { return .thinking }
        if date < speakingUntil { return .speaking }
        if error != nil { return .error }
        if drafting { return .listening }
        return .idle
    }

    static let maxMessages = 40

    /// How long the head "speaks" a reply: about reading pace, within limits.
    static func speakingSeconds(_ reply: String) -> TimeInterval {
        min(9, max(1.2, Double(reply.count) * 0.045))
    }

    /// The base64 part of a `data:image/...;base64,` URL, or nil when it isn't one.
    static func dataURLPayload(_ dataURL: String) -> String? {
        guard dataURL.hasPrefix("data:image/"), let range = dataURL.range(of: ";base64,") else { return nil }
        let payload = String(dataURL[range.upperBound...])
        return payload.isEmpty ? nil : payload
    }
}
