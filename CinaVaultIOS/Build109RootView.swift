import SwiftUI

struct Build109RootView: View {
    @ObservedObject var model: CinaVaultModel
    @Binding var recoveryDiagnostic: String?

    var body: some View {
        Group {
            if let diagnostic = recoveryDiagnostic {
                VStack(spacing: 18) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.cyan)
                    Text("Recovery check")
                        .font(.title.bold())
                    Text(diagnostic)
                        .font(.caption.monospaced())
                    Button("Continue") {
                        recoveryDiagnostic = nil
                        model.navigate(.library)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if model.session == nil {
                Build109LoginView(model: model)
            } else {
                Build109Shell(model: model)
            }
        }
        .preferredColorScheme(.dark)
        .background(Color(red: 0.01, green: 0.02, blue: 0.05))
    }
}

private struct Build109LoginView: View {
    @ObservedObject var model: CinaVaultModel
    @State private var endpoint = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accessKey = ""
    @State private var useAccessKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section("CinaVault Premium · v2.11 Build 1.11") {
                    TextField("Server URL", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Use access key", isOn: $useAccessKey)
                    if useAccessKey {
                        SecureField("Access key", text: $accessKey)
                    } else {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                    }
                }
                Section {
                    Button(model.loading ? "Connecting…" : "Connect securely") {
                        if useAccessKey {
                            model.loginWithAccessKey(endpoint: endpoint, accessKey: accessKey)
                        } else {
                            model.loginWithPassword(endpoint: endpoint, email: email, password: password)
                        }
                    }
                    .disabled(model.loading || endpoint.isEmpty || (useAccessKey ? accessKey.isEmpty : email.isEmpty || password.isEmpty))
                }
                Section("Status") {
                    Text(model.statusMessage)
                    if let error = model.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Enter the Vault")
        }
    }
}

private struct Build109Shell: View {
    @ObservedObject var model: CinaVaultModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Build109LibraryView(model: model)
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }
                .tag(0)

            Build109AIView(model: model)
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(1)

            Build111HFModelsView(model: model)
                .tabItem { Label("HF Models", systemImage: "brain.head.profile") }
                .tag(4)

            Build109SecurityView(model: model)
                .tabItem { Label("Security", systemImage: "shield.lefthalf.filled") }
                .tag(2)

            Build109SettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .overlay(alignment: .top) {
            if model.loading || model.refreshing {
                ProgressView(model.statusMessage)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
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

private struct Build111HFModelsView: View {
    @ObservedObject var model: CinaVaultModel
    @State private var query = ""
    private let models = [
        "Qwen/Qwen3-4B-Instruct-2507",
        "HuggingFaceTB/SmolLM3-3B",
        "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
        "microsoft/Phi-3.5-mini-instruct",
        "katanemo/Arch-Router-1.5B:hf-inference"
    ]

    var body: some View {
        NavigationStack {
            List(models.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { modelID in
                VStack(alignment: .leading, spacing: 8) {
                    Text(modelID).font(.headline)
                    Text("Free · Public · Ungated").font(.caption).foregroundStyle(.secondary)
                    Link("Select / inspect model", destination: URL(string: "https://huggingface.co/\(modelID)")!)
                }
            }
            .searchable(text: $query, prompt: "Search models")
            .navigationTitle("Hugging Face Models")
            .safeAreaInset(edge: .bottom) {
                Text("HF token: \(model.hfTokenStatus)").font(.caption).padding(8).background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

private struct Build109LibraryView: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        NavigationStack {
            List(model.filteredLibrary) { item in
                Button {
                    model.open(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text([item.year.map(String.init), item.genre, item.resolution].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $model.searchQuery, prompt: "Search the vault")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await model.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if model.filteredLibrary.isEmpty {
                    ContentUnavailableView("No media found", systemImage: "externaldrive", description: Text("Refresh after the Windows server finishes scanning sources."))
                }
            }
        }
    }
}

private struct Build109AIView: View {
    @ObservedObject var model: CinaVaultModel
    @State private var catalogQuery = ""

    private var catalogURL: URL? {
        var components = URLComponents(string: "https://huggingface.co/models")
        var items = [
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "sort", value: "trending")
        ]
        if !catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "search", value: catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        components?.queryItems = items
        return components?.url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("AI scanner") {
                    Toggle("AI Autopilot", isOn: Binding(
                        get: { model.preferences.aiAutopilotEnabled },
                        set: { model.setAutopilotEnabled($0) }
                    ))
                    Button {
                        model.runAutopilotNow()
                    } label: {
                        Label("Run scanner now", systemImage: "sparkles")
                    }
                    .disabled(!model.preferences.aiAutopilotEnabled)

                    Button(role: .destructive) {
                        model.setAutopilotEnabled(false)
                    } label: {
                        Label("Stop AI scanner", systemImage: "stop.fill")
                    }
                    .disabled(!model.preferences.aiAutopilotEnabled)
                }

                Section("Hugging Face Model Catalog") {
                    TextField("Model or publisher", text: $catalogQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let catalogURL {
                        Link(destination: catalogURL) {
                            Label("Open model catalog", systemImage: "magnifyingglass")
                        }
                    }
                    Text("HF token: \(model.hfTokenStatus)")
                        .font(.caption)
                    Text("Providers: \(model.metadataProviderStatus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Library health") {
                    LabeledContent("Media records", value: String(model.library.count))
                    LabeledContent("Missing artwork", value: String(model.library.filter { $0.artworkUrl?.isEmpty != false }.count))
                    LabeledContent("Unverified", value: String(model.library.filter { !$0.verified }.count))
                }
            }
            .navigationTitle("AI Autopilot")
        }
    }
}

private struct Build109SecurityView: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        NavigationStack {
            Form {
                Section("VPN") {
                    Label("Use the iOS Settings VPN profile for device-wide protection.", systemImage: "network.badge.shield.half.filled")
                    Link("Open iOS VPN settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    Text("A signed Network Extension entitlement and provider configuration are required before the app can create or control a tunnel directly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Connection") {
                    LabeledContent("Transport", value: model.serverInfo?.remoteTransport ?? "HTTPS relay")
                    LabeledContent("Session", value: model.session == nil ? "Disconnected" : "Encrypted")
                }
            }
            .navigationTitle("Security")
        }
    }
}

private struct Build109SettingsView: View {
    @ObservedObject var model: CinaVaultModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Build") {
                    LabeledContent("Release", value: "v2.11 Build 1.11")
                    LabeledContent("Version", value: "2.0.11 (111)")
                }
                Section("Automation") {
                    Toggle("Automatic refresh", isOn: Binding(
                        get: { model.preferences.automaticRefreshEnabled },
                        set: { value in model.updatePreferences { $0.automaticRefreshEnabled = value } }
                    ))
                }
                Section {
                    Button("Sign out", role: .destructive) { model.logout() }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
