import Foundation

// The agent's photo face, ported from CinaVault Premium's portraitAvatar.ts so
// the iPhone head moves like the desktop one. The owner's photo is laid over a
// grid whose points carry jaw, eyelid, brow and depth weights worked out from
// three markers (both eyes and the mouth). Everything here is pure math.

struct PortraitPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct PortraitCalibration: Codable, Equatable {
    var leftEye: PortraitPoint
    var rightEye: PortraitPoint
    var mouth: PortraitPoint
}

struct PortraitPose: Equatable {
    var yaw = 0.0
    var pitch = 0.0
    var roll = 0.0
    var blink = 0.0
    var brow = 0.0
    var mouth = 0.0
}

enum AgentMood: Equatable {
    case idle, listening, thinking, speaking, error
}

/// Depth, jaw, eyelid, brow, lip gap and head mask for one photo point, each 0...1.
struct PortraitWeights: Equatable {
    var depth: Double
    var jaw: Double
    var lid: Double
    var brow: Double
    var gap: Double
    var head: Double
}

struct FaceFrame: Equatable {
    var origin: PortraitPoint
    var across: PortraitPoint
    var down: PortraitPoint
    var eyeDistance: Double
    var mouthDistance: Double
}

struct PortraitView: Equatable {
    var center: PortraitPoint
    var height: Double
}

enum PortraitMath {
    static let jawDrop = 0.14
    static let lidTravel = 0.07
    static let browLift = 0.045
    static let parallax = 0.12

    static func faceFrame(_ cal: PortraitCalibration, aspect: Double = 1) -> FaceFrame {
        let ex = (cal.rightEye.x - cal.leftEye.x) * aspect
        let ey = cal.rightEye.y - cal.leftEye.y
        let eyeDistance = hypot(ex, ey)
        let across = eyeDistance > 0 ? PortraitPoint(x: ex / eyeDistance, y: ey / eyeDistance) : PortraitPoint(x: 1, y: 0)
        let down = PortraitPoint(x: -across.y, y: across.x)
        let origin = PortraitPoint(x: (cal.leftEye.x + cal.rightEye.x) / 2, y: (cal.leftEye.y + cal.rightEye.y) / 2)
        let mouthDistance = (cal.mouth.x - origin.x) * aspect * down.x + (cal.mouth.y - origin.y) * down.y
        return FaceFrame(origin: origin, across: across, down: down, eyeDistance: eyeDistance, mouthDistance: mouthDistance)
    }

    /// Why a set of markers can't drive the face, or nil when it can. Same rules as the desktop.
    static func calibrationError(_ cal: PortraitCalibration, aspect: Double = 1) -> String? {
        let points = [cal.leftEye, cal.rightEye, cal.mouth]
        if points.contains(where: { !$0.x.isFinite || !$0.y.isFinite || !(0 ... 1).contains($0.x) || !(0 ... 1).contains($0.y) }) {
            return "Keep the markers on the photo."
        }
        if cal.leftEye.x >= cal.rightEye.x { return "The left eye marker must be left of the right eye marker." }
        let frame = faceFrame(cal, aspect: aspect)
        if frame.eyeDistance < 0.04 { return "Move the eye markers apart, onto each eye." }
        if frame.mouthDistance < frame.eyeDistance * 0.45 { return "Move the mouth marker down onto the mouth." }
        if frame.mouthDistance > frame.eyeDistance * 2.5 { return "The mouth marker is too far from the eyes." }
        return nil
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private static func gauss(_ value: Double, _ width: Double) -> Double {
        exp(-(value * value) / (2 * width * width))
    }

    static func weights(_ f: FaceFrame, u: Double, v: Double, aspect: Double) -> PortraitWeights {
        let d = f.eyeDistance
        let m = f.mouthDistance
        let dx = (u - f.origin.x) * aspect
        let dy = v - f.origin.y
        let a = dx * f.across.x + dy * f.across.y
        let b = dx * f.down.x + dy * f.down.y

        let ex = a / (d * 1.05)
        let ey = (b - m * 0.4) / (m * 1.55)
        let inside = 1 - (ex * ex + ey * ey)
        var depth = inside > 0 ? inside.squareRoot() * smoothstep(0, 0.25, inside) : 0
        depth += 0.35 * gauss(a, d * 0.16) * gauss(b - m * 0.55, m * 0.3) * smoothstep(0, 0.3, inside)
        depth = min(1, depth)

        let t = (b - m) / m
        let jaw = smoothstep(-0.04, 0.06, t) * (1 - smoothstep(0.55, 0.85, t)) * gauss(a, d * 0.62)

        var lid = 0.0
        var brow = 0.0
        for side in [-1.0, 1.0] {
            let ea = a - side * d * 0.5
            let above = -b
            lid = max(lid, gauss(ea, d * 0.15) * smoothstep(-0.06 * d, 0, above) * (1 - smoothstep(0.05 * d, 0.13 * d, above)))
            brow = max(brow, gauss(ea, d * 0.26) * gauss(above - 0.24 * d, 0.1 * d))
        }

        let gap = gauss(a, d * 0.2) * gauss(t, 0.03)

        let ha = a / (d * 1.4)
        let hb = (b - m * 0.2) / (m * 2.05)
        let neck = gauss(a, d * 0.55) * smoothstep(m * 1.0, m * 1.6, b) * (1 - smoothstep(m * 2.2, m * 2.8, b))
        let head = max(1 - smoothstep(0.75, 1.05, hypot(ha, hb)), neck)
        return PortraitWeights(depth: depth, jaw: jaw, lid: lid, brow: brow, gap: gap, head: head)
    }

    static func weights(_ cal: PortraitCalibration, u: Double, v: Double, aspect: Double = 1) -> PortraitWeights {
        weights(faceFrame(cal, aspect: aspect), u: u, v: v, aspect: aspect)
    }

    /// Where one photo point lands (in photo coordinates) for a pose.
    static func deform(_ f: FaceFrame, _ w: PortraitWeights, u: Double, v: Double, pose: PortraitPose, aspect: Double) -> PortraitPoint {
        let down = w.jaw * pose.mouth * jawDrop * f.mouthDistance
            + w.lid * pose.blink * lidTravel * f.eyeDistance
            - w.brow * pose.brow * browLift * f.eyeDistance
        var x = (u - f.origin.x) * aspect + f.down.x * down
        var y = v - f.origin.y + f.down.y * down
        x += sin(pose.yaw) * w.depth * parallax
        y += sin(pose.pitch) * w.depth * parallax
        let c = cos(pose.roll)
        let s = sin(pose.roll)
        return PortraitPoint(x: (x * c - y * s) / aspect + f.origin.x, y: x * s + y * c + f.origin.y)
    }

    static func deform(_ cal: PortraitCalibration, u: Double, v: Double, pose: PortraitPose, aspect: Double = 1) -> PortraitPoint {
        let f = faceFrame(cal, aspect: aspect)
        return deform(f, weights(f, u: u, v: v, aspect: aspect), u: u, v: v, pose: pose, aspect: aspect)
    }

    /// Deterministic blinking: a quick blink every few seconds, sometimes twice.
    static func blinkAt(_ seconds: Double) -> Double {
        let period = 3.6
        let cycle = (seconds / period).rounded(.down)
        let hash = abs(sin(cycle * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let local = seconds - cycle * period - hash * 1.4
        func one(_ at: Double) -> Double {
            let p = (local - at) / 0.16
            return p < 0 || p > 1 ? 0 : 1 - abs(p * 2 - 1)
        }
        return max(one(0), hash > 0.7 ? one(0.3) : 0)
    }

    static func pose(_ mood: AgentMood, seconds: Double, mouth: Double = 0, reduceMotion: Bool = false) -> PortraitPose {
        if reduceMotion {
            switch mood {
            case .listening: return PortraitPose(brow: 0.5)
            case .error: return PortraitPose(brow: -0.6)
            default: return PortraitPose()
            }
        }
        let swayYaw = sin(seconds * 0.5) * 0.05
        let swayPitch = sin(seconds * 0.37) * 0.025
        let blink = blinkAt(seconds)
        switch mood {
        case .listening:
            return PortraitPose(yaw: swayYaw, pitch: swayPitch, roll: 0.05, blink: blink, brow: 0.55, mouth: 0)
        case .thinking:
            return PortraitPose(
                yaw: sin(seconds * 1.1) * 0.08,
                pitch: -0.06 + sin(seconds * 0.8) * 0.015,
                roll: sin(seconds * 0.6) * 0.02,
                blink: max(0.3, blink),
                brow: 0.3,
                mouth: 0
            )
        case .speaking:
            return PortraitPose(
                yaw: swayYaw,
                pitch: swayPitch + sin(seconds * 5) * 0.025 * mouth,
                roll: 0,
                blink: blink,
                brow: 0.15 + mouth * 0.25,
                mouth: min(1, max(0, mouth))
            )
        case .error:
            return PortraitPose(yaw: sin(seconds * 3) * 0.04, pitch: 0.03, roll: 0, blink: blink, brow: -0.7, mouth: 0)
        case .idle:
            return PortraitPose(yaw: swayYaw, pitch: swayPitch, roll: 0, blink: blink, brow: 0, mouth: 0)
        }
    }

    /// Frames the face so a full-body or off-centre photo still shows a close-up.
    static func view(_ cal: PortraitCalibration, aspect: Double = 1) -> PortraitView {
        let f = faceFrame(cal, aspect: aspect)
        let m = max(f.mouthDistance, 1e-3)
        let offset = m * 0.75
        return PortraitView(
            center: PortraitPoint(x: f.origin.x + f.down.x * offset / aspect, y: f.origin.y + f.down.y * offset),
            height: min(1.5, m * 5.4)
        )
    }

    /// A synthetic speech envelope for text the phone shows rather than speaks.
    static func speechMouth(_ seconds: Double) -> Double {
        let syllable = (sin(seconds * 13) + 1) / 2
        let phrase = (sin(seconds * 2.3) + 1) / 2
        return (0.25 + 0.75 * syllable) * (0.45 + 0.55 * phrase)
    }
}

/// A cols x rows grid over the photo with its weights worked out once. Each
/// frame only moves the vertices and recolours them for the pose.
struct PortraitMesh {
    let aspect: Double
    let cols: Int
    let rows: Int
    private let frame: FaceFrame
    private let weights: [PortraitWeights]

    var vertexCount: Int { (cols + 1) * (rows + 1) }

    init(calibration: PortraitCalibration, aspect: Double, cols: Int = 32, rows: Int = 32) {
        self.aspect = aspect
        self.cols = cols
        self.rows = rows
        let frame = PortraitMath.faceFrame(calibration, aspect: aspect)
        self.frame = frame
        weights = (0 ..< (cols + 1) * (rows + 1)).map { index in
            let u = Double(index % (cols + 1)) / Double(cols)
            let v = Double(index / (cols + 1)) / Double(rows)
            return PortraitMath.weights(frame, u: u, v: v, aspect: aspect)
        }
    }

    /// Two triangles per cell, as indices into the vertex grid.
    func indices() -> [UInt16] {
        var result: [UInt16] = []
        result.reserveCapacity(cols * rows * 6)
        for row in 0 ..< rows {
            for col in 0 ..< cols {
                let i = row * (cols + 1) + col
                result += [i, i + 1, i + cols + 1, i + 1, i + cols + 2, i + cols + 1].map { UInt16($0) }
            }
        }
        return result
    }

    /// Interleaved vertices for the renderer: position x, y (photo coordinates),
    /// texture u, v, then the colour the photo is multiplied by (r, g, b, a). The
    /// head keeps its natural colour, the rest of the photo fades into a dim cyan
    /// hologram, and the gap between the lips darkens as the mouth opens.
    func vertices(for pose: PortraitPose) -> [Float] {
        var out = [Float](repeating: 0, count: vertexCount * PortraitMesh.floatsPerVertex)
        for index in 0 ..< vertexCount {
            let u = Double(index % (cols + 1)) / Double(cols)
            let v = Double(index / (cols + 1)) / Double(rows)
            let w = weights[index]
            let point = PortraitMath.deform(frame, w, u: u, v: v, pose: pose, aspect: aspect)
            let head = min(1, max(0, w.head))
            let shade = 1 - 0.55 * w.gap * pose.mouth
            let base = index * PortraitMesh.floatsPerVertex
            out[base] = Float(point.x)
            out[base + 1] = Float(point.y)
            out[base + 2] = Float(u)
            out[base + 3] = Float(v)
            out[base + 4] = Float((80 + 175 * head) / 255 * shade)
            out[base + 5] = Float((220 + 35 * head) / 255 * shade)
            out[base + 6] = Float(shade)
            out[base + 7] = Float((46 + 209 * head) / 255)
        }
        return out
    }

    static let floatsPerVertex = 8
}
