import Foundation
import SwiftUI

struct ClientPreferences: Codable, Equatable {
    var motionEnabled = true
    var denseGridEnabled = true
    var aiAutopilotEnabled = true
    var automaticRefreshEnabled = true
    var preferAirPlay = true
}

struct ArtworkRequestIdentity: Hashable {
    let mediaKey: String
    let artworkPath: String?
    let refreshRevision: UInt64
}

@MainActor
final class CinaVaultModel: ObservableObject {
    @Published private(set) var session: RemoteSession?
    @Published private(set) var serverInfo: ServerInfo?
    @Published private(set) var library: [MediaItem] = []
    @Published private(set) var controlSnapshot = ControlSnapshot.unavailable(
        "The server has not synchronized mobile controls yet."
    )
    @Published private(set) var lumaSiftProgress = LumaSiftProgress.ready
    @Published private(set) var lumaSiftPlan: LumaSiftPlan?

    // SwiftUI's global @ViewBuilder router is evaluated from a nonisolated helper.
    // Reads are safe because all mutations remain confined to setDestination(_:) on MainActor.
    nonisolated(unsafe) private(set) var destination: AppDestination = .library
    @Published private var navigationRevision: UInt64 = 0

    @Published var selectedMedia: MediaItem?
    @Published var searchQuery = ""
    @Published var loading = false
    @Published var refreshing = false
    @Published var runningControlAction: String?
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published var commandPaletteOpen = false
    @Published var preferences: ClientPreferences
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var artworkRefreshRevision: UInt64 = 0

    private let api = CinaVaultAPI()
    private let keychain = KeychainSessionStore()
    private let preferencesKey = "cinavault_ios_preferences_v2"
    private var automaticRefreshTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(ClientPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = ClientPreferences()
        }

        session = keychain.load()
        if session != nil {
            loading = true
            Task { await refresh() }
        }
        configureAutomaticRefresh()
    }

    deinit {
        automaticRefreshTask?.cancel()
    }

    var filteredLibrary: [MediaItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return library }
        return library.filter { item in
            [
                item.title,
                item.mediaType,
                item.year.map(String.init),
                item.genre,
                item.resolution,
                item.codec,
            ]
            .compactMap { $0 }
            .contains { $0.lowercased().contains(query) }
        }
    }

    var hfTokenStatus: String {
        controlSnapshot.section(.intelligence)?.metrics.first {
            $0.label.localizedCaseInsensitiveContains("token")
        }?.value ?? "Managed by Windows secure store"
    }

    var metadataProviderStatus: String {
        controlSnapshot.section(.extensions)?.metrics.first {
            $0.label.localizedCaseInsensitiveContains("provider")
                || $0.label.localizedCaseInsensitiveContains("metadata")
        }?.value ?? "Startup readiness synchronized from Windows"
    }

    func loginWithPassword(endpoint: String, email: String, password: String) {
        authenticate(status: "Signing in securely") {
            try await self.api.loginWithPassword(endpoint: endpoint, email: email, password: password)
        }
    }

    func loginWithAccessKey(endpoint: String, accessKey: String) {
        authenticate(status: "Validating encrypted access key") {
            try await self.api.loginWithAccessKey(endpoint: endpoint, accessKey: accessKey)
        }
    }

    func logout() {
        automaticRefreshTask?.cancel()
        keychain.clear()
        session = nil
        serverInfo = nil
        library = []
        artworkRefreshRevision &+= 1
        controlSnapshot = .unavailable("Sign in to synchronize controls.")
        lumaSiftProgress = .ready
        lumaSiftPlan = nil
        selectedMedia = nil
        setDestination(.library)
        statusMessage = "Signed out"
        errorMessage = nil
    }

    func navigate(_ destination: AppDestination) {
        setDestination(destination)
        commandPaletteOpen = false
        errorMessage = nil
    }

    func open(_ item: MediaItem) {
        selectedMedia = item
        setDestination(.player)
        statusMessage = "Opening \(item.title)"
    }

    func refresh() async {
        guard let session else { return }
        refreshing = true
        errorMessage = nil
        statusMessage = "Synchronizing encrypted library and controls"

        do {
            async let serverInfoRequest = api.loadServerInfo(session: session)
            async let libraryRequest = api.loadLibrary(session: session)
            let controlsTask = Task {
                try? await api.loadControlSnapshot(session: session)
            }
            let (serverInfo, mediaItems) = try await (serverInfoRequest, libraryRequest)
            let controls = await controlsTask.value ?? .unavailable(
                "The Windows server has not enabled authenticated mobile control endpoints yet."
            )

            self.serverInfo = serverInfo
            let refreshedLibrary = preferences.aiAutopilotEnabled ? smartSort(mediaItems) : mediaItems
            library = refreshedLibrary
            artworkRefreshRevision &+= 1
            if let selected = selectedMedia {
                selectedMedia = refreshedLibrary.first { $0.mediaKey == selected.mediaKey } ?? selected
            }
            controlSnapshot = controls
            refreshing = false
            loading = false
            lastRefreshDate = Date()
            statusMessage = controls.available
                ? "\(library.count) encrypted media records and controls synchronized"
                : "\(library.count) encrypted media records synchronized; \(controls.message)"
        } catch {
            refreshing = false
            loading = false
            errorMessage = error.localizedDescription
            statusMessage = "Remote synchronization needs attention"
        }
    }

    func refreshLumaSift() {
        guard let session else { return }
        Task {
            do {
                async let progressRequest = api.loadLumaSiftProgress(session: session)
                async let planRequest = api.loadLumaSiftPlan(session: session)
                let (progress, plan) = try await (progressRequest, planRequest)
                lumaSiftProgress = progress
                lumaSiftPlan = plan
                statusMessage = progress.message
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "LumaSift needs attention"
            }
        }
    }

    func startLumaSift(selectedTypes: [String]) {
        guard let session, runningControlAction == nil else { return }
        guard !selectedTypes.isEmpty else {
            errorMessage = "Choose at least one LumaSift file type before starting a scan."
            return
        }
        runningControlAction = "lumasift.start"
        errorMessage = nil
        statusMessage = "LumaSift is preparing a read-only exact-duplicate plan"
        Task {
            do {
                statusMessage = try await api.startLumaSift(session: session, selectedTypes: selectedTypes)
                runningControlAction = nil
                refreshLumaSift()
            } catch {
                runningControlAction = nil
                errorMessage = error.localizedDescription
                statusMessage = "LumaSift needs attention"
            }
        }
    }

    func applyLumaSiftPlan(_ planID: String) {
        guard let session, runningControlAction == nil, !planID.isEmpty else { return }
        runningControlAction = "lumasift.apply"
        errorMessage = nil
        statusMessage = "LumaSift is revalidating and moving approved files to quarantine"
        Task {
            do {
                statusMessage = try await api.applyLumaSiftPlan(session: session, planID: planID)
                runningControlAction = nil
                refreshLumaSift()
                await refresh()
            } catch {
                runningControlAction = nil
                errorMessage = error.localizedDescription
                statusMessage = "LumaSift needs attention"
            }
        }
    }

    func runControlAction(_ actionID: String) {
        guard let session, runningControlAction == nil, !actionID.isEmpty else { return }
        runningControlAction = actionID
        errorMessage = nil
        statusMessage = "Running secure control action"

        Task {
            do {
                statusMessage = try await api.runControlAction(session: session, actionID: actionID)
                runningControlAction = nil
                await refresh()
            } catch {
                runningControlAction = nil
                errorMessage = error.localizedDescription
                statusMessage = "Control action needs attention"
            }
        }
    }

    func runAutopilotNow() {
        if let action = controlSnapshot.section(.intelligence)?.actions.first(where: {
            $0.id == "ai.run-now" && $0.enabled
        }) {
            runControlAction(action.id)
            return
        }
        statusMessage = "AI Autopilot is reconciling remote library state"
        Task { await refresh() }
    }

    func setAutopilotEnabled(_ enabled: Bool) {
        preferences.aiAutopilotEnabled = enabled
        persistPreferences()
        library = enabled ? smartSort(library) : library.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        statusMessage = enabled ? "AI Autopilot enabled" : "AI Autopilot paused on this device"
    }

    func updatePreferences(_ transform: (inout ClientPreferences) -> Void) {
        transform(&preferences)
        persistPreferences()
        configureAutomaticRefresh()
    }

    func artworkData(for item: MediaItem) async throws -> Data? {
        guard let session, let path = item.artworkUrl, !path.isEmpty else { return nil }
        return try await api.loadArtwork(session: session, path: path)
    }

    func streamURL(for item: MediaItem) throws -> URL? {
        guard let session else { return nil }
        return try api.absoluteURL(session: session, path: item.streamUrl)
    }

    func createCastGrant(for item: MediaItem) async throws -> CastGrant {
        guard let session else { throw CinaVaultAPIError.invalidResponse }
        return try await api.createCastGrant(session: session, mediaKey: item.mediaKey)
    }

    func clearError() {
        errorMessage = nil
    }

    private func setDestination(_ destination: AppDestination) {
        guard self.destination != destination else { return }
        self.destination = destination
        navigationRevision &+= 1
    }

    private func authenticate(
        status: String,
        operation: @escaping () async throws -> RemoteSession
    ) {
        loading = true
        errorMessage = nil
        statusMessage = status
        Task {
            do {
                let session = try await operation()
                try keychain.save(session)
                self.session = session
                loading = false
                statusMessage = "Secure account session established"
                configureAutomaticRefresh()
                await refresh()
            } catch {
                loading = false
                errorMessage = error.localizedDescription
                statusMessage = "Authentication failed"
            }
        }
    }

    private func smartSort(_ items: [MediaItem]) -> [MediaItem] {
        items.sorted { left, right in
            if left.favorite != right.favorite { return left.favorite && !right.favorite }
            if left.verified != right.verified { return left.verified && !right.verified }
            if left.dateAdded != right.dateAdded { return left.dateAdded > right.dateAdded }
            return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
        }
    }

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }
    }

    private func configureAutomaticRefresh() {
        automaticRefreshTask?.cancel()
        guard preferences.automaticRefreshEnabled, session != nil else { return }
        automaticRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }
}
