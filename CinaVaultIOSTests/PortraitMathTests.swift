import Metal
import XCTest
@testable import CinaVaultIOS

final class PortraitMathTests: XCTestCase {
    private let face = PortraitCalibration(
        leftEye: PortraitPoint(x: 0.4, y: 0.4),
        rightEye: PortraitPoint(x: 0.6, y: 0.4),
        mouth: PortraitPoint(x: 0.5, y: 0.6)
    )

    func testNeutralPoseLeavesThePhotoAlone() {
        for point in [PortraitPoint(x: 0.1, y: 0.1), PortraitPoint(x: 0.5, y: 0.6), PortraitPoint(x: 0.45, y: 0.4)] {
            let moved = PortraitMath.deform(face, u: point.x, v: point.y, pose: PortraitPose())
            XCTAssertEqual(moved.x, point.x, accuracy: 1e-9)
            XCTAssertEqual(moved.y, point.y, accuracy: 1e-9)
        }
    }

    func testOpenMouthDropsTheChinButNotTheEyes() {
        let open = PortraitPose(mouth: 1)
        XCTAssertGreaterThan(PortraitMath.deform(face, u: 0.5, v: 0.66, pose: open).y, 0.67)
        XCTAssertEqual(PortraitMath.deform(face, u: 0.4, v: 0.4, pose: open).y, 0.4, accuracy: 1e-3)
    }

    func testBlinkLowersTheLidsAndBrowsLift() {
        XCTAssertGreaterThan(PortraitMath.deform(face, u: 0.4, v: 0.39, pose: PortraitPose(blink: 1)).y, 0.39)
        XCTAssertLessThan(PortraitMath.deform(face, u: 0.4, v: 0.352, pose: PortraitPose(brow: 1)).y, 0.352)
    }

    func testTurningMovesTheNoseMoreThanTheBackground() {
        let turn = PortraitPose(yaw: 0.2)
        XCTAssertGreaterThan(PortraitMath.deform(face, u: 0.5, v: 0.5, pose: turn).x - 0.5, 0.01)
        XCTAssertEqual(PortraitMath.deform(face, u: 0.02, v: 0.02, pose: turn).x, 0.02, accuracy: 1e-6)
    }

    func testMarkersAreValidatedLikeTheDesktop() {
        XCTAssertNil(PortraitMath.calibrationError(face))
        var swapped = face
        swapped.leftEye = PortraitPoint(x: 0.7, y: 0.4)
        XCTAssertNotNil(PortraitMath.calibrationError(swapped))
        var crowded = face
        crowded.mouth = PortraitPoint(x: 0.5, y: 0.42)
        XCTAssertNotNil(PortraitMath.calibrationError(crowded))
        var off = face
        off.mouth = PortraitPoint(x: 0.5, y: 1.2)
        XCTAssertNotNil(PortraitMath.calibrationError(off))
        let tall = PortraitCalibration(
            leftEye: PortraitPoint(x: 0.45, y: 0.2),
            rightEye: PortraitPoint(x: 0.55, y: 0.2),
            mouth: PortraitPoint(x: 0.5, y: 0.25)
        )
        XCTAssertNil(PortraitMath.calibrationError(tall, aspect: 1000.0 / 1500.0))
    }

    func testBlinksStayInRangeAndHappen() {
        var closed = 0
        for step in 0 ..< 3000 {
            let blink = PortraitMath.blinkAt(Double(step) * 0.01)
            XCTAssertTrue((0 ... 1).contains(blink))
            if blink > 0.9 { closed += 1 }
        }
        XCTAssertGreaterThan(closed, 0)
    }

    func testMoodsShapeThePose() {
        XCTAssertGreaterThan(PortraitMath.pose(.listening, seconds: 1).brow, 0.4)
        XCTAssertGreaterThanOrEqual(PortraitMath.pose(.thinking, seconds: 1).blink, 0.3)
        XCTAssertLessThan(PortraitMath.pose(.error, seconds: 1).brow, 0)
        XCTAssertEqual(PortraitMath.pose(.speaking, seconds: 1, mouth: 0.8).mouth, 0.8, accuracy: 1e-9)
        let still = PortraitMath.pose(.speaking, seconds: 3, mouth: 1, reduceMotion: true)
        XCTAssertEqual(still.yaw, 0)
        XCTAssertEqual(still.mouth, 0)
        for step in 0 ... 200 {
            XCTAssertTrue((0 ... 1).contains(PortraitMath.speechMouth(Double(step) * 0.05)))
        }
    }

    func testFullBodyPhotosAreFramedAsACloseUp() {
        let body = PortraitCalibration(
            leftEye: PortraitPoint(x: 0.46, y: 0.2),
            rightEye: PortraitPoint(x: 0.54, y: 0.2),
            mouth: PortraitPoint(x: 0.5, y: 0.25)
        )
        let view = PortraitMath.view(body, aspect: 1000.0 / 1500.0)
        XCTAssertLessThan(view.height, 0.5)
        XCTAssertTrue((0.2 ... 0.35).contains(view.center.y))
        XCTAssertEqual(view.center.x, 0.5, accuracy: 1e-9)
    }

    func testMeshFillsTheGridAndFadesTheBackground() {
        let mesh = PortraitMesh(calibration: face, aspect: 1, cols: 8, rows: 8)
        XCTAssertEqual(mesh.vertexCount, 81)
        XCTAssertEqual(mesh.indices().count, 8 * 8 * 6)
        XCTAssertEqual(mesh.indices().max(), 80)
        let vertices = mesh.vertices(for: PortraitPose())
        let stride = PortraitMesh.floatsPerVertex
        XCTAssertEqual(vertices.count, 81 * stride)
        // The last vertex is the photo's bottom-right corner, at rest.
        XCTAssertEqual(vertices[80 * stride], 1, accuracy: 1e-5)
        XCTAssertEqual(vertices[80 * stride + 1], 1, accuracy: 1e-5)
        let cornerAlpha = vertices[stride - 1]
        let centreAlpha = vertices[(4 * 9 + 4) * stride + 7]
        XCTAssertLessThan(cornerAlpha, 0.32)
        XCTAssertEqual(centreAlpha, 1, accuracy: 1e-5)
    }

    func testTheHeadShaderCompiles() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal is not available on this test host")
        }
        XCTAssertNoThrow(try PortraitRenderer.makePipeline(device: device, pixelFormat: .bgra8Unorm))
    }

    func testAgentStateExplainsWhyItCannotAnswer() {
        XCTAssertNotNil(AgentState().unavailableReason)
        let off = AgentStatus(enabled: false, configured: true, hasFace: false, messagesPerHour: 40)
        XCTAssertTrue(AgentState(status: off).unavailableReason?.contains("turned off") == true)
        let noKey = AgentStatus(enabled: true, configured: false, hasFace: false, messagesPerHour: 40)
        XCTAssertTrue(AgentState(status: noKey).unavailableReason?.contains("API key") == true)
        let ready = AgentStatus(enabled: true, configured: true, hasFace: true, messagesPerHour: 40)
        XCTAssertNil(AgentState(status: ready).unavailableReason)
    }

    func testMoodFollowsTheConversation() {
        let now = Date()
        var state = AgentState()
        XCTAssertEqual(state.mood(at: now, drafting: false), .idle)
        XCTAssertEqual(state.mood(at: now, drafting: true), .listening)
        state.sending = true
        XCTAssertEqual(state.mood(at: now, drafting: true), .thinking)
        state.sending = false
        state.speakingUntil = now.addingTimeInterval(2)
        XCTAssertEqual(state.mood(at: now, drafting: false), .speaking)
        XCTAssertEqual(state.mood(at: now.addingTimeInterval(3), drafting: false), .idle)
    }

    func testRepliesSpeakAtReadingPaceAndFaceURLsAreChecked() {
        XCTAssertEqual(AgentState.speakingSeconds("Hi"), 1.2, accuracy: 1e-9)
        XCTAssertEqual(AgentState.speakingSeconds(String(repeating: "x", count: 1000)), 9, accuracy: 1e-9)
        XCTAssertEqual(AgentState.dataURLPayload("data:image/jpeg;base64,AAAA"), "AAAA")
        XCTAssertNil(AgentState.dataURLPayload("https://example.com/face.jpg"))
        XCTAssertNil(AgentState.dataURLPayload("data:image/jpeg;base64,"))
    }

    func testAgentFaceDecodesFromTheServerContract() throws {
        let json = #"{"leftEye":{"x":0.4,"y":0.4},"rightEye":{"x":0.6,"y":0.4},"mouth":{"x":0.5,"y":0.65}}"#
        let calibration = try JSONDecoder().decode(PortraitCalibration.self, from: Data(json.utf8))
        XCTAssertEqual(calibration.mouth.y, 0.65)
        let status = try JSONDecoder().decode(
            AgentStatus.self,
            from: Data(#"{"enabled":true,"configured":false,"hasFace":true,"messagesPerHour":40}"#.utf8)
        )
        XCTAssertTrue(status.hasFace)
        XCTAssertFalse(status.configured)
    }
}
