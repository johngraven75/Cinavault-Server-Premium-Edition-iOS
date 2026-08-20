import AVKit
import SwiftUI
import UIKit

struct CinaVaultRootView: View {
    @ObservedObject var model: CinaVaultModel
    @Binding var recoveryDiagnostic: String?

    var body: some View {
        Group {
            if let diagnostic = recoveryDiagnostic {
                RecoveryView(diagnostic: diagnostic) {
                    recoveryDiagnostic = nil
                    model.navigate(.library)
                }
            } else if model.session == nil {
                LoginView(model: model)
            } else {
                SpatialShell(model: model)
            }
        }
        .background(CVColor.ink)
        .preferredColorScheme(.dark)
    }
}

private struct LoginView: View {
    @ObservedObject var model: CinaVaultModel
    @State private var endpoint = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accessKey = ""
    @State private var method = 0

    var body: some View {
        ZStack {
            SpatialBackground(motionEnabled: model.preferences.motionEnabled)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("CINAVAULT PREMIUM")
                            .font(.caption.weight(.black))
                            .tracking(3)
                            .foregroundStyle(CVColor.cyan)
                        Text("Enter the Vault")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(CVColor.text)
                        Text("Connect through the encrypted CinaVault HTTPS relay. Local file names and paths never leave the server.")
                            .font(.subheadline)
                            .foregroundStyle(CVColor.muted)
                    }

                    TextField("https://vault.example.com", text: $endpoint)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .cvTextField()

                    Picker("Authentication", selection: $method) {
                        Text("Password").tag(0)
                        Text("Access Key").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if method == 0 {
                        TextField("Account email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .cvTextField()
                        SecureField("Account password", text: $password)
                            .textContentType(.password)
                            .cvTextField()
                    } else {
                        SecureField("CinaVault access key", text: $accessKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .cvTextField()
                    }

                    Button {
                        if method == 0 {
                            model.loginWithPassword(endpoint: endpoint, email: email, password: password)
                        } else {
                            model.loginWithAccessKey(endpoint: endpoint, accessKey: accessKey)
                        }
                    } label: {
                        HStack {
                            if model.loading { ProgressView().tint(CVColor.ink) }
                            Text(model.loading ? "Connecting" : "Connect securely")
                                .fontWeight(.black)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .padding(15)
                        .foregroundStyle(CVColor.ink)
                        .background(
                            LinearGradient(colors: [CVColor.cyan, CVColor.orchid], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                        )
                    }
                    .disabled(model.loading || endpoint.isEmpty || (method == 0 ? (email.isEmpty || password.isEmpty) : accessKey.isEmpty))

                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(CVColor.muted)

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red: 1, green: 0.43, blue: 0.53))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(24)
                .cvPanel(accent: CVColor.cyan, radius: 28)
                .frame(maxWidth: 620)
                .padding(20)
            }
        }
    }
}

private struct SpatialShell: View {
    @ObservedObject var model: CinaVaultModel
    @StateObject private var castCoordinator = CastCoordinator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 820
            ZStack {
                SpatialBackground(motionEnabled: model.preferences.motionEnabled && !reduceMotion)
                if wide {
                    HStack(spacing: 10) {
                        NavigationRail(model: model)
                            .frame(width: 104)
                        ExperienceFrame(model: model, castCoordinator: castCoordinator, wide: true)
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 0) {
                        ExperienceFrame(model: model, castCoordinator: castCoordinator, wide: false)
                        CompactNavigation(model: model)
                    }
                }

                if model.loading {
                    LoadingOverlay(message: model.statusMessage)
                }

                if model.commandPaletteOpen {
                    CommandPalette(model: model)
                        .transition(.opacity)
                        .zIndex(20)
                }

                Button("") { model.commandPaletteOpen.toggle() }
                    .keyboardShortcut("k", modifiers: [.command])
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
                    .accessibilityHidden(true)
            }
            .background(CVColor.ink)
            .animation(
                model.preferences.motionEnabled && !reduceMotion ? .easeOut(duration: 0.18) : nil,
                value: model.destination
            )
        }
        .alert("CinaVault needs attention", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.clearError() } }
        )) {
            Button("Close", role: .cancel) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }
}

private struct ExperienceFrame: View {
    @ObservedObject var model: CinaVaultModel
    @ObservedObject var castCoordinator: CastCoordinator
    let wide: Bool

    var body: some View {
        VStack(spacing: 10) {
            CommandDeck(model: model)
            ContextStage(model: model)
            DestinationView(model: model, castCoordinator: castCoordinator)
                .id(model.destination)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(wide ? 14 : 10)
        .background(CVColor.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: wide ? 28 : 0, style: .continuous))
        .overlay {
            if wide {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }
        }
    }
}

private struct CommandDeck: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [CVColor.cyan, CVColor.orchid], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .foregroundStyle(CVColor.ink)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 1) {
                Text("CINAVAULT")
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.7)
                    .foregroundStyle(CVColor.cyan)
                Text(model.destination.label)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(CVColor.text)
                    .lineLimit(1)
            }

            TextField("Search the vault", text: $model.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(CVColor.ink.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(CVColor.text)

            Button { model.commandPaletteOpen = true } label: {
                Image(systemName: "command.square.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CVColor.cyan)
            .accessibilityLabel("Open command palette")

            AirPlayRouteButton()
                .frame(width: 34, height: 34)
                .accessibilityLabel("AirPlay devices")

            GoogleCastRouteButton()
                .frame(width: 34, height: 34)
                .accessibilityLabel("Google Cast devices")

            Button { Task { await model.refresh() } } label: {
                if model.refreshing {
                    ProgressView().tint(CVColor.cyan)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(CVColor.text)
            .accessibilityLabel("Refresh")
        }
        .padding(8)
        .background(CVColor.ink.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08)) }
    }
}

private struct ContextStage: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.destination.eyebrow)
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.7)
                    .foregroundStyle(CVColor.cyan)
                Text(model.destination == .player ? (model.selectedMedia?.title ?? "Now Playing") : model.destination.stageTitle)
                    .font(.title2.weight(.black))
                    .foregroundStyle(CVColor.text)
                    .lineLimit(1)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(CVColor.muted)
                    .lineLimit(1)
            }
            Spacer()
            StatusChip(value: String(model.library.count), label: "Items", accent: CVColor.cyan)
            StatusChip(value: model.serverInfo?.localPathsExposed == true ? "Check" : "Safe", label: "Privacy", accent: CVColor.emerald)
            StatusChip(value: model.preferences.aiAutopilotEnabled ? "Live" : "Paused", label: "AI", accent: CVColor.magenta)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [CVColor.cyan.opacity(0.09), CVColor.orchid.opacity(0.1), CVColor.magenta.opacity(0.07)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 21)
        )
        .overlay { RoundedRectangle(cornerRadius: 21).stroke(CVColor.cyan.opacity(0.14)) }
    }
}

@ViewBuilder
private func DestinationView(model: CinaVaultModel, castCoordinator: CastCoordinator) -> some View {
    switch model.destination {
    case .library:
        LibraryView(model: model)
    case .player:
        PlayerView(model: model, castCoordinator: castCoordinator)
    case .casting:
        CastingView(model: model, castCoordinator: castCoordinator)
    case .intelligence:
        IntelligenceView(model: model)
    case .settings:
        SettingsView(model: model)
    case .remote:
        RemoteView(model: model)
    case .sources, .downloads, .liveTV, .server, .security, .advanced, .cloudNAS, .extensions:
        ControlDestinationView(model: model, destination: model.destination)
    }
}

private struct NavigationRail: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [CVColor.cyan, CVColor.magenta], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .foregroundStyle(CVColor.ink)
            }
            .frame(width: 52, height: 52)
            .padding(.vertical, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(AppDestination.primary) { destination in
                        Button { model.navigate(destination) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: destination.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(destination.shortLabel)
                                    .font(.system(size: 7, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(model.destination == destination ? CVColor.cyan : CVColor.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                model.destination == destination ? CVColor.cyan.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 13)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button { model.logout() } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(CVColor.muted)
                    .padding(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign out")
        }
        .padding(8)
        .background(CVColor.panel.opacity(0.98), in: RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.09)) }
    }
}

private struct CompactNavigation: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppDestination.compact) { destination in
                Button { model.navigate(destination) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: destination.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(destination.shortLabel)
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundStyle(model.destination == destination ? CVColor.cyan : CVColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            Button { model.commandPaletteOpen = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("More").font(.system(size: 7, weight: .semibold))
                }
                .foregroundStyle(model.destination == .player || model.destination == .casting ? CVColor.cyan : CVColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .background(CVColor.ink)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }
}

private struct CommandPalette: View {
    @ObservedObject var model: CinaVaultModel
    @State private var query = ""

    private var destinations: [AppDestination] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return AppDestination.primary }
        return AppDestination.primary.filter {
            $0.label.lowercased().contains(normalized) || $0.parityID.contains(normalized)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.008, green: 0.016, blue: 0.051).opacity(0.98)
                .ignoresSafeArea()
                .onTapGesture { model.commandPaletteOpen = false }

            VStack(spacing: 10) {
                TextField("Go anywhere in CinaVault", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(CVColor.panelElevated, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(CVColor.text)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(destinations) { destination in
                            Button { model.navigate(destination) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: destination.symbol)
                                        .foregroundStyle(model.destination == destination ? CVColor.cyan : CVColor.orchid)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(destination.label)
                                            .font(.subheadline.weight(.black))
                                            .foregroundStyle(CVColor.text)
                                        Text(destination.eyebrow)
                                            .font(.system(size: 8, weight: .bold))
                                            .tracking(1)
                                            .foregroundStyle(CVColor.muted)
                                    }
                                    Spacer()
                                    if model.destination == destination {
                                        Text("ACTIVE")
                                            .font(.system(size: 7, weight: .black))
                                            .foregroundStyle(CVColor.cyan)
                                    }
                                }
                                .padding(13)
                                .background(CVColor.panel, in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text("Command+K toggles this surface on hardware keyboards")
                        .font(.caption2)
                        .foregroundStyle(CVColor.muted)
                    Spacer()
                    Button("Close") { model.commandPaletteOpen = false }
                        .foregroundStyle(CVColor.cyan)
                }
            }
            .padding(14)
            .frame(maxWidth: 680, maxHeight: 720)
            .background(CVColor.ink, in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(CVColor.cyan.opacity(0.3)) }
            .padding(20)
        }
        .background(CVColor.ink)
    }
}

private struct LibraryView: View {
    @ObservedObject var model: CinaVaultModel

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: model.preferences.denseGridEnabled ? 104 : 154), spacing: 10)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 13) {
                ForEach(model.filteredLibrary) { item in
                    Button { model.open(item) } label: {
                        MediaCard(model: model, item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
        .overlay {
            if model.filteredLibrary.isEmpty && !model.refreshing {
                ContentUnavailableView(
                    "The Vault is empty",
                    systemImage: "film.stack",
                    description: Text("Add and scan a source from Media Sources or run AI Autopilot.")
                )
                .foregroundStyle(CVColor.muted)
            }
        }
    }
}

private struct MediaCard: View {
    @ObservedObject var model: CinaVaultModel
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                AuthenticatedArtwork(model: model, item: item)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                if item.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(CVColor.emerald)
                        .padding(7)
                        .background(CVColor.ink.opacity(0.82), in: Circle())
                        .padding(6)
                }
            }
            Text(item.title)
                .font(.caption.weight(.black))
                .foregroundStyle(CVColor.text)
                .lineLimit(2)
            Text([item.year.map(String.init), item.resolution, item.genre].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(CVColor.muted)
                .lineLimit(1)
        }
        .padding(8)
        .cvPanel(accent: item.favorite ? CVColor.magenta : CVColor.cyan, radius: 18)
    }
}

private struct AuthenticatedArtwork: View {
    @ObservedObject var model: CinaVaultModel
    let item: MediaItem
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [CVColor.panelElevated, CVColor.ink], startPoint: .top, endPoint: .bottom)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "film.fill")
                        .font(.largeTitle)
                        .foregroundStyle(CVColor.orchid)
                    Text("AI artwork")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CVColor.muted)
                }
            }
        }
        .clipped()
        .task(id: ArtworkRequestIdentity(
            mediaKey: item.mediaKey,
            artworkPath: item.artworkUrl,
            refreshRevision: model.artworkRefreshRevision
        )) {
            image = nil
            guard let data = try? await model.artworkData(for: item) else { return }
            image = UIImage(data: data)
        }
    }
}

private struct PlayerView: View {
    @ObservedObject var model: CinaVaultModel
    @ObservedObject var castCoordinator: CastCoordinator
    @State private var player: AVPlayer?
    @State private var grant: CastGrant?
    @State private var playbackError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(minHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .cvPanel(accent: CVColor.cyan, radius: 22)
                } else {
                    ZStack {
                        CVColor.ink
                        VStack(spacing: 10) {
                            ProgressView().tint(CVColor.cyan)
                            Text(playbackError ?? "Requesting a temporary encrypted playback grant")
                                .font(.caption)
                                .foregroundStyle(playbackError == nil ? CVColor.muted : Color.red)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                    }
                    .frame(minHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                HStack(spacing: 12) {
                    AirPlayRouteButton().frame(width: 44, height: 44)
                    GoogleCastRouteButton().frame(width: 44, height: 44)
                    Button("Cast now") {
                        guard let media = model.selectedMedia,
                              let grant,
                              let session = model.session else { return }
                        castCoordinator.cast(media: media, grant: grant, session: session)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CVColor.magenta)
                    .disabled(grant == nil)
                    Spacer()
                }

                Text(model.selectedMedia?.title ?? "No media selected")
                    .font(.title2.weight(.black))
                    .foregroundStyle(CVColor.text)
                Text(model.selectedMedia?.overview ?? "Select a media card from the Library.")
                    .font(.subheadline)
                    .foregroundStyle(CVColor.muted)
                Text(castCoordinator.statusMessage)
                    .font(.caption)
                    .foregroundStyle(CVColor.cyan)
            }
            .padding(.bottom, 24)
        }
        .task(id: model.selectedMedia?.mediaKey) {
            player?.pause()
            player = nil
            grant = nil
            playbackError = nil
            guard let media = model.selectedMedia,
                  let session = model.session else { return }
            do {
                let newGrant = try await model.createCastGrant(for: media)
                guard let url = resolvedHTTPSURL(newGrant.streamUrl, baseURL: session.endpoint) else {
                    throw CinaVaultAPIError.insecureURL
                }
                grant = newGrant
                let newPlayer = AVPlayer(url: url)
                player = newPlayer
                newPlayer.play()
            } catch {
                playbackError = error.localizedDescription
            }
        }
        .onDisappear { player?.pause() }
    }
}

private struct CastingView: View {
    @ObservedObject var model: CinaVaultModel
    @ObservedObject var castCoordinator: CastCoordinator
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "airplayvideo.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(CVColor.magenta)
                    VStack(alignment: .leading) {
                        Text("Casting Center")
                            .font(.title2.weight(.black))
                            .foregroundStyle(CVColor.text)
                        Text("Automatic AirPlay and Google Cast discovery with secure temporary stream grants.")
                            .font(.subheadline)
                            .foregroundStyle(CVColor.muted)
                    }
                }
                .padding(18)
                .cvPanel(accent: CVColor.magenta)

                HStack(spacing: 18) {
                    VStack {
                        AirPlayRouteButton().frame(width: 60, height: 60)
                        Text("AirPlay").font(.caption.weight(.bold)).foregroundStyle(CVColor.text)
                    }
                    VStack {
                        GoogleCastRouteButton().frame(width: 60, height: 60)
                        Text("Google Cast").font(.caption.weight(.bold)).foregroundStyle(CVColor.text)
                    }
                }
                .padding(18)
                .cvPanel(accent: CVColor.cyan)

                Text(model.selectedMedia?.title ?? "No media selected")
                    .font(.title3.weight(.black))
                    .foregroundStyle(CVColor.text)
                Text(castCoordinator.statusMessage)
                    .font(.caption)
                    .foregroundStyle(CVColor.muted)

                Button {
                    guard let media = model.selectedMedia,
                          let session = model.session else { return }
                    working = true
                    Task {
                        defer { working = false }
                        do {
                            let grant = try await model.createCastGrant(for: media)
                            castCoordinator.cast(media: media, grant: grant, session: session)
                        } catch {
                            model.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        if working { ProgressView().tint(CVColor.ink) }
                        Text("Cast selected media").fontWeight(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(CVColor.ink)
                .background(CVColor.magenta, in: RoundedRectangle(cornerRadius: 16))
                .disabled(model.selectedMedia == nil || working)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct RemoteView: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    StatusChip(value: "HTTPS", label: "Transport", accent: CVColor.emerald)
                    StatusChip(value: "Opaque", label: "Media keys", accent: CVColor.magenta)
                    StatusChip(value: model.serverInfo?.localPathsExposed == true ? "Check" : "Hidden", label: "Local paths", accent: CVColor.solar)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 9) {
                    DetailRow(label: "Endpoint", value: model.session?.endpoint.absoluteString ?? "Unavailable")
                    DetailRow(label: "Account", value: model.session?.email ?? "Unavailable")
                    DetailRow(label: "Relay", value: model.serverInfo?.remoteTransport ?? "HTTPS relay")
                    DetailRow(label: "Server", value: "\(model.serverInfo?.version ?? "") · \(model.serverInfo?.build ?? "")")
                }
                .padding(16)
                .cvPanel(accent: CVColor.cyan)

                ControlSectionView(model: model, destination: .remote)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct IntelligenceView: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                Toggle(isOn: Binding(
                    get: { model.preferences.aiAutopilotEnabled },
                    set: model.setAutopilotEnabled
                )) {
                    VStack(alignment: .leading) {
                        Text("Autonomous media management")
                            .font(.headline.weight(.black))
                            .foregroundStyle(CVColor.text)
                        Text("Automatically refresh, sort, repair, and prioritize the encrypted library.")
                            .font(.caption)
                            .foregroundStyle(CVColor.muted)
                    }
                }
                .tint(CVColor.magenta)
                .padding(16)
                .cvPanel(accent: CVColor.magenta)

                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "HF token", value: model.hfTokenStatus)
                    DetailRow(label: "Providers", value: model.metadataProviderStatus)
                    Text("Provider secrets remain in the Windows secure store; iOS receives readiness and enriched media over authenticated HTTPS.")
                        .font(.caption)
                        .foregroundStyle(CVColor.muted)
                }
                .padding(16)
                .cvPanel(accent: CVColor.cyan)

                HStack(spacing: 10) {
                    StatusChip(value: String(model.library.filter { $0.artworkUrl == nil }.count), label: "Artwork", accent: CVColor.magenta)
                    StatusChip(value: String(model.library.filter { !$0.verified }.count), label: "Unverified", accent: CVColor.solar)
                    StatusChip(value: String(model.library.filter(\.favorite).count), label: "Priority", accent: CVColor.emerald)
                }

                Button { model.runAutopilotNow() } label: {
                    Label("Run Autopilot now", systemImage: "sparkles")
                        .fontWeight(.black)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(CVColor.ink)
                .background(CVColor.magenta, in: RoundedRectangle(cornerRadius: 16))

                ControlSectionView(model: model, destination: .intelligence)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PreferenceToggle(
                    title: "Motion and animated graphics",
                    subtitle: "Uses compositor-safe movement without full-screen blur or scale transitions.",
                    isOn: model.preferences.motionEnabled
                ) { value in model.updatePreferences { $0.motionEnabled = value } }
                PreferenceToggle(
                    title: "Compact media cards",
                    subtitle: "Keeps the library dense and adaptive across iPhone and iPad.",
                    isOn: model.preferences.denseGridEnabled
                ) { value in model.updatePreferences { $0.denseGridEnabled = value } }
                PreferenceToggle(
                    title: "Automatic library refresh",
                    subtitle: "Synchronizes encrypted library and controls every five minutes.",
                    isOn: model.preferences.automaticRefreshEnabled
                ) { value in model.updatePreferences { $0.automaticRefreshEnabled = value } }
                PreferenceToggle(
                    title: "Prefer AirPlay",
                    subtitle: "Keeps native Apple playback routing prominent while retaining Google Cast.",
                    isOn: model.preferences.preferAirPlay
                ) { value in model.updatePreferences { $0.preferAirPlay = value } }

                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Account", value: model.session?.email ?? "Unavailable")
                    DetailRow(label: "Session storage", value: "Apple Keychain · This device only")
                    DetailRow(label: "Transport", value: "HTTPS required")
                    DetailRow(label: "Build", value: "v2 Build 2 · parity contract v1")
                }
                .padding(16)
                .cvPanel(accent: CVColor.cyan)

                ControlSectionView(model: model, destination: .settings)

                Button(role: .destructive) { model.logout() } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                        .padding(13)
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct PreferenceToggle: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let setValue: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: setValue)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline.weight(.black)).foregroundStyle(CVColor.text)
                Text(subtitle).font(.caption).foregroundStyle(CVColor.muted)
            }
        }
        .tint(CVColor.cyan)
        .padding(15)
        .cvPanel(accent: CVColor.cyan)
    }
}

private struct ControlDestinationView: View {
    @ObservedObject var model: CinaVaultModel
    let destination: AppDestination

    var body: some View {
        ScrollView {
            ControlSectionView(model: model, destination: destination)
                .padding(.bottom, 24)
        }
    }
}

private struct ControlSectionView: View {
    @ObservedObject var model: CinaVaultModel
    let destination: AppDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(CVColor.cyan)
                    .frame(width: 58, height: 58)
                    .background(CVColor.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading) {
                    Text(destination.stageTitle)
                        .font(.title2.weight(.black))
                        .foregroundStyle(CVColor.text)
                    Text(destination.eyebrow)
                        .font(.system(size: 8, weight: .black))
                        .tracking(1.4)
                        .foregroundStyle(CVColor.cyan)
                }
                Spacer()
                Text(model.controlSnapshot.section(destination) == nil ? "PENDING" : "LIVE")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(model.controlSnapshot.section(destination) == nil ? CVColor.solar : CVColor.emerald)
            }
            .padding(16)
            .cvPanel(accent: CVColor.cyan)

            if let section = model.controlSnapshot.section(destination), model.controlSnapshot.available {
                Text(section.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(CVColor.muted)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 9)], spacing: 9) {
                    ForEach(section.metrics, id: \.self) { metric in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(metric.value)
                                .font(.headline.weight(.black))
                                .foregroundStyle(CVColor.text)
                            Text(metric.label.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(metricColor(metric.status))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cvPanel(accent: metricColor(metric.status), radius: 16)
                    }
                }

                ForEach(section.actions) { action in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.label)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(CVColor.text)
                            Text(action.description)
                                .font(.caption)
                                .foregroundStyle(CVColor.muted)
                        }
                        Spacer()
                        Button {
                            model.runControlAction(action.id)
                        } label: {
                            if model.runningControlAction == action.id {
                                ProgressView().tint(CVColor.ink)
                            } else {
                                Text("Run").fontWeight(.black)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(action.dangerous ? Color.red : CVColor.cyan)
                        .disabled(!action.enabled || model.runningControlAction != nil)
                    }
                    .padding(14)
                    .cvPanel(accent: action.dangerous ? Color.red : CVColor.cyan, radius: 17)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CONTROL ENDPOINT PENDING")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(CVColor.solar)
                    Text(model.controlSnapshot.message)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(CVColor.text)
                    Text("This destination matches the Windows design, but no action is represented as available until the authenticated server control API confirms support.")
                        .font(.caption)
                        .foregroundStyle(CVColor.muted)
                }
                .padding(17)
                .cvPanel(accent: CVColor.solar)
            }
        }
    }

    private func metricColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "warning": CVColor.solar
        case "error", "critical": .red
        case "success", "healthy": CVColor.emerald
        default: CVColor.cyan
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(CVColor.muted)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CVColor.text)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

private struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            CVColor.ink.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(CVColor.cyan)
                Text(message)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CVColor.text)
            }
            .padding(24)
            .cvPanel(accent: CVColor.cyan)
        }
        .zIndex(30)
    }
}

struct RecoveryView: View {
    let diagnostic: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            SpatialBackground(motionEnabled: false)
            VStack(alignment: .leading, spacing: 14) {
                Text("CINAVAULT RECOVERY")
                    .font(.caption.weight(.black))
                    .tracking(2)
                    .foregroundStyle(CVColor.cyan)
                Text("The previous session ended unexpectedly")
                    .font(.title.weight(.black))
                    .foregroundStyle(CVColor.text)
                Text("Account data, Keychain session material, settings, and library records were preserved. Continue safely to the Library.")
                    .font(.subheadline)
                    .foregroundStyle(CVColor.muted)
                Text("Diagnostic: \(diagnostic)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CVColor.magenta)
                Button("Return to Library", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(CVColor.cyan)
                    .foregroundStyle(CVColor.ink)
            }
            .padding(24)
            .frame(maxWidth: 620)
            .cvPanel(accent: CVColor.cyan, radius: 28)
            .padding(20)
        }
    }
}

private extension View {
    func cvTextField() -> some View {
        padding(14)
            .background(CVColor.ink.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.09)) }
            .foregroundStyle(CVColor.text)
    }
}

private func resolvedHTTPSURL(_ path: String, baseURL: URL) -> URL? {
    if let absolute = URL(string: path), absolute.scheme != nil {
        return absolute.scheme?.lowercased() == "https" ? absolute : nil
    }
    let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
    guard let url = URL(string: normalized, relativeTo: baseURL.appendingPathComponent("/"))?.absoluteURL,
          url.scheme?.lowercased() == "https" else {
        return nil
    }
    return url
}
