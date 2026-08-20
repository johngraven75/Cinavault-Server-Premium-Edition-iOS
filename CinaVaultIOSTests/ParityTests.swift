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
}
