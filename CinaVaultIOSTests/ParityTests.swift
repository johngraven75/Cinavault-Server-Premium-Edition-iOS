import XCTest
@testable import CinaVaultIOS

final class ParityTests: XCTestCase {
    func testPrimaryDestinationsMatchWindowsReference() {
        XCTAssertEqual(
            AppDestination.primary.map(\.parityID),
            [
                "library",
                "sources",
                "downloads",
                "live-tv",
                "server",
                "security",
                "remote",
                "advanced",
                "cloud-nas",
                "extensions",
                "ai-autopilot",
                "settings",
            ]
        )
    }

    func testControlSnapshotFailsClosedWhenUnavailable() {
        let snapshot = ControlSnapshot.unavailable("Control API pending")
        XCTAssertFalse(snapshot.available)
        XCTAssertTrue(snapshot.sections.isEmpty)
        XCTAssertNil(snapshot.section(.sources))
    }

    func testClientPreferencesKeepAutomationAndDenseCardsEnabled() {
        let preferences = ClientPreferences()
        XCTAssertTrue(preferences.motionEnabled)
        XCTAssertTrue(preferences.denseGridEnabled)
        XCTAssertTrue(preferences.aiAutopilotEnabled)
        XCTAssertTrue(preferences.automaticRefreshEnabled)
    }

    func testMediaIdentityUsesOpaqueMediaKey() {
        let item = MediaItem(
            mediaKey: "opaque-key",
            title: "Test",
            mediaType: "movie",
            year: nil,
            rating: nil,
            overview: nil,
            genre: nil,
            duration: nil,
            fileSize: nil,
            resolution: nil,
            codec: nil,
            verified: false,
            watched: false,
            favorite: false,
            dateAdded: "",
            lastPlayed: nil,
            tmdbId: nil,
            imdbId: nil,
            artworkUrl: "/api/artwork/opaque-key",
            streamUrl: "/api/stream/opaque-key"
        )
        XCTAssertEqual(item.id, "opaque-key")
        XCTAssertFalse(item.streamUrl.contains("C:\\"))
        XCTAssertFalse(item.streamUrl.contains("/Users/"))
    }

    func testArtworkRequestIdentityChangesAfterLibraryRefresh() {
        let before = ArtworkRequestIdentity(
            mediaKey: "opaque-key",
            artworkPath: "/api/artwork/opaque-key",
            refreshRevision: 9
        )
        let after = ArtworkRequestIdentity(
            mediaKey: "opaque-key",
            artworkPath: "/api/artwork/opaque-key",
            refreshRevision: 10
        )

        XCTAssertNotEqual(before, after)
    }

    func testReleaseLabelMatchesWindowsBuild() {
        // The Windows reference moved to beta-3; the iOS bundle itself is
        // unchanged, so bundleVersion stays 1.0.3 (1003).
        XCTAssertEqual(CinaVaultRelease.displayName, "v2.1.7 Beta 3 Build 217")
        // Tests run hosted in the app, so this reads the app's own Info.plist.
        XCTAssertEqual(CinaVaultRelease.bundleVersion, "1.0.3 (1003)")
    }

    func testBeta3PortStatusIsHonest() {
        let entries = PlatformParity.entries
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        XCTAssertTrue(entries.allSatisfy { !$0.note.isEmpty && !$0.windowsFeature.isEmpty })
        XCTAssertEqual(PlatformParity.windowsDisplayName, CinaVaultRelease.displayName)
        // A duplicate claim would list no gaps. This table must keep naming
        // what is left behind until it is genuinely ported.
        XCTAssertTrue(entries.contains { $0.status == .leftBehind })
        XCTAssertTrue(entries.contains { $0.id == "vault" && $0.status == .leftBehind })
        XCTAssertTrue(entries.contains { $0.id == "wireguard" && $0.status == .leftBehind })
        XCTAssertTrue(entries.contains { $0.id == "google-drive" && $0.status == .leftBehind })
        XCTAssertTrue(entries.contains { $0.id == "metadata-actions" && $0.status == .leftBehind })
    }
}
