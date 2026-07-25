import SwiftUI

enum CVColor {
    static let ink = Color(red: 0.008, green: 0.016, blue: 0.039)
    static let panel = Color(red: 0.031, green: 0.051, blue: 0.11)
    static let panelElevated = Color(red: 0.063, green: 0.102, blue: 0.208)
    static let cyan = Color(red: 0.412, green: 0.969, blue: 1.0)
    static let blue = Color(red: 0.306, green: 0.486, blue: 1.0)
    static let orchid = Color(red: 0.722, green: 0.361, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.31, blue: 0.812)
    static let solar = Color(red: 1.0, green: 0.784, blue: 0.341)
    static let emerald = Color(red: 0.384, green: 1.0, blue: 0.761)
    static let text = Color(red: 0.969, green: 0.98, blue: 1.0)
    static let muted = Color(red: 0.604, green: 0.659, blue: 0.773)
}

struct SpatialBackground: View {
    let motionEnabled: Bool
    @State private var phase = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CVColor.ink, Color(red: 0.031, green: 0.012, blue: 0.102), Color(red: 0.012, green: 0.082, blue: 0.125)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(RadialGradient(colors: [CVColor.blue.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: 300))
                .frame(width: 620, height: 620)
                .offset(x: phase ? -170 : -230, y: phase ? -300 : -230)

            Circle()
                .fill(RadialGradient(colors: [CVColor.magenta.opacity(0.23), .clear], center: .center, startRadius: 0, endRadius: 260))
                .frame(width: 540, height: 540)
                .offset(x: phase ? 230 : 170, y: phase ? -180 : -250)

            Canvas { context, size in
                let spacing: CGFloat = 46
                var x: CGFloat = 0
                while x <= size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height * 0.38))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(CVColor.cyan.opacity(0.055)), lineWidth: 1)
                    x += spacing
                }
                var y = size.height * 0.38
                while y <= size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(CVColor.orchid.opacity(0.05)), lineWidth: 1)
                    y += spacing
                }
            }
        }
        .ignoresSafeArea()
        .background(CVColor.ink)
        .onAppear {
            guard motionEnabled else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
        .onChange(of: motionEnabled) { _, enabled in
            if enabled {
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) {
                    phase.toggle()
                }
            } else {
                withAnimation(.none) { phase = false }
            }
        }
    }
}

struct GlassPanelModifier: ViewModifier {
    var accent: Color = CVColor.cyan
    var radius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(CVColor.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(accent.opacity(0.19), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 18, y: 10)
    }
}

extension View {
    func cvPanel(accent: Color = CVColor.cyan, radius: CGFloat = 22) -> some View {
        modifier(GlassPanelModifier(accent: accent, radius: radius))
    }
}

struct StatusChip: View {
    let value: String
    let label: String
    let accent: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(CVColor.text)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(CVColor.ink.opacity(0.72), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
