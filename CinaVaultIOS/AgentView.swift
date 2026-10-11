import MetalKit
import SwiftUI
import UIKit

/// The CinaVault agent on iPhone and iPad: the owner's photo face (or the
/// hologram orb when there is none) above a short chat with the server's agent.
struct AgentView: View {
    @ObservedObject var model: CinaVaultModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var draft = ""
    @FocusState private var composing: Bool

    private var reduceMotion: Bool { systemReduceMotion || !model.preferences.motionEnabled }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 0.25)) { context in
                        let mood = model.agent.mood(at: context.date, drafting: !draft.isEmpty)
                        VStack(spacing: 8) {
                            AgentHead(face: model.agent.face, mood: mood, reduceMotion: reduceMotion)
                                .frame(height: 260)
                                .frame(maxWidth: .infinity)
                                .background(CVColor.ink, in: RoundedRectangle(cornerRadius: 20))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay { RoundedRectangle(cornerRadius: 20).stroke(CVColor.cyan.opacity(0.18)) }
                                .accessibilityElement()
                                .accessibilityLabel("Agent head, \(label(for: mood))")
                            Text(label(for: mood))
                                .font(.caption)
                                .foregroundStyle(CVColor.muted)
                        }
                    }

                    ForEach(model.agent.messages) { message in
                        HStack {
                            if !message.fromAgent { Spacer(minLength: 40) }
                            Text(message.text)
                                .font(.callout)
                                .foregroundStyle(message.fromAgent ? CVColor.text : CVColor.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    message.fromAgent ? Color.white.opacity(0.07) : CVColor.cyan,
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .textSelection(.enabled)
                            if message.fromAgent { Spacer(minLength: 40) }
                        }
                    }

                    if let error = model.agent.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color(red: 1, green: 0.56, blue: 0.66))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let status = model.agent.status, model.agent.unavailableReason == nil {
                        Text("Answers come from your CinaVault server. From the phone the agent can look things up but not change anything. Up to \(status.messagesPerHour) messages an hour.")
                            .font(.caption2)
                            .foregroundStyle(CVColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(CVColor.ink)
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle("Agent")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.resetAgentConversation() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Start a new conversation")
                    .disabled(model.agent.messages.isEmpty || model.agent.sending)
                }
            }
        }
        .onAppear { model.loadAgent() }
    }

    private var canSend: Bool {
        model.agent.unavailableReason == nil && !model.agent.sending
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField(model.agent.unavailableReason ?? "Ask about your library", text: $draft, axis: .vertical)
                .lineLimit(1 ... 4)
                .focused($composing)
                .submitLabel(.send)
                .onSubmit(send)
                .disabled(model.agent.unavailableReason != nil)
                .padding(10)
                .background(CVColor.panel, in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: draft) { _, value in
                    if value.count > 2_000 { draft = String(value.prefix(2_000)) }
                }
            if model.agent.sending {
                ProgressView().tint(CVColor.cyan).frame(width: 40, height: 40)
            } else {
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .frame(width: 40, height: 40)
                        .foregroundStyle(CVColor.ink)
                        .background(canSend ? CVColor.cyan : CVColor.muted.opacity(0.4), in: Circle())
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(CVColor.ink)
    }

    private func send() {
        guard canSend else { return }
        model.sendAgentMessage(draft)
        draft = ""
    }

    private func label(for mood: AgentMood) -> String {
        if let reason = model.agent.unavailableReason { return reason }
        switch mood {
        case .thinking: return "Thinking…"
        case .speaking: return "Answering"
        case .listening: return "Listening"
        case .error: return "Something went wrong"
        case .idle: return "Ready"
        }
    }
}

/// The photo face when one is set, otherwise the hologram orb.
private struct AgentHead: View {
    let face: AgentFace?
    let mood: AgentMood
    let reduceMotion: Bool

    var body: some View {
        if let face {
            PortraitHeadView(face: face, mood: mood, reduceMotion: reduceMotion)
        } else {
            HologramOrb(mood: mood, reduceMotion: reduceMotion)
                .frame(width: 180, height: 180)
        }
    }
}

/// Hosts the Metal renderer; a plain photo stands in if Metal is unavailable.
private struct PortraitHeadView: UIViewRepresentable {
    let face: AgentFace
    let mood: AgentMood
    let reduceMotion: Bool

    final class Coordinator {
        var renderer: PortraitRenderer?
        var photo: Data?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        install(in: container, coordinator: context.coordinator)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if context.coordinator.photo != face.photo {
            install(in: container, coordinator: context.coordinator)
        }
        context.coordinator.renderer?.mood = mood
        context.coordinator.renderer?.reduceMotion = reduceMotion
        (container.subviews.first as? MTKView)?.preferredFramesPerSecond = reduceMotion ? 10 : 30
    }

    private func install(in container: UIView, coordinator: Coordinator) {
        container.subviews.forEach { $0.removeFromSuperview() }
        coordinator.photo = face.photo
        coordinator.renderer = nil
        guard let image = UIImage(data: face.photo), let cgImage = image.cgImage else { return }

        let mtkView = MTKView(frame: container.bounds)
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtkView.clearColor = MTLClearColor(red: 0.008, green: 0.016, blue: 0.039, alpha: 1)
        mtkView.preferredFramesPerSecond = 30
        if let renderer = PortraitRenderer(view: mtkView, photo: cgImage, calibration: face.calibration) {
            mtkView.delegate = renderer
            coordinator.renderer = renderer
            container.addSubview(mtkView)
        } else {
            let still = UIImageView(image: image)
            still.frame = container.bounds
            still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            still.contentMode = .scaleAspectFill
            container.addSubview(still)
        }
    }
}

/// The hologram orb shown until the owner sets a face on the desktop.
private struct HologramOrb: View {
    let mood: AgentMood
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let pulse: Double
                switch mood {
                case .speaking: pulse = PortraitMath.speechMouth(seconds)
                case .thinking: pulse = (sin(seconds * 3) + 1) / 2
                default: pulse = reduceMotion ? 0.25 : (sin(seconds * 1.2) + 1) / 4
                }
                let tint = mood == .error ? CVColor.magenta : CVColor.cyan
                let radius = min(size.width, size.height) / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                canvas.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [tint.opacity(0.55 + 0.3 * pulse), .clear]),
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                let core = radius * (0.32 + 0.1 * pulse)
                canvas.fill(
                    Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)),
                    with: .color(tint.opacity(0.9))
                )
            }
        }
    }
}
