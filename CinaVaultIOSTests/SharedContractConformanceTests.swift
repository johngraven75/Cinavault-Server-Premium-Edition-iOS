import CryptoKit
import Foundation
import XCTest
@testable import CinaVaultIOS

@MainActor
final class SharedContractConformanceTests: XCTestCase {
    func testMetadataProviderGoldenFileHashAndRoundTrip() throws {
        let data = try fixtureData(named: "metadata-provider-registry.json")
        XCTAssertEqual(sha256(data), metadataProviderFixtureSHA256)

        let decoded = try JSONDecoder().decode(MetadataProviderRegistryContract.self, from: data)
        try decoded.validated()

        let encoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try canonicalJSON(encoded), try canonicalJSON(data))
        XCTAssertEqual(decoded.providers.map { provider in provider.id }, ["tvmaze", "tmdb"])
        XCTAssertTrue(decoded.providers.allSatisfy { provider in provider.enabled })
    }

    func testArtworkGoldenFileHashAndRoundTrip() throws {
        let data = try fixtureData(named: "artwork-cache-entry.json")
        XCTAssertEqual(sha256(data), artworkCacheFixtureSHA256)

        let decoded = try JSONDecoder().decode(ArtworkCacheEntryContract.self, from: data)
        try decoded.validated()

        let encoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try canonicalJSON(encoded), try canonicalJSON(data))
        XCTAssertFalse(decoded.localPathExposed)
        XCTAssertTrue(decoded.deliveryPath.hasPrefix("/api/artwork/"))
    }

    func testArtworkContractRejectsLocalPathExposure() throws {
        let data = try fixtureData(named: "artwork-cache-entry.json")
        let decoded = try JSONDecoder().decode(ArtworkCacheEntryContract.self, from: data)
        let invalid = ArtworkCacheEntryContract(
            schemaVersion: decoded.schemaVersion,
            mediaKey: decoded.mediaKey,
            kind: decoded.kind,
            mimeType: decoded.mimeType,
            byteLength: decoded.byteLength,
            sha256: decoded.sha256,
            width: decoded.width,
            height: decoded.height,
            sourceProvider: decoded.sourceProvider,
            cacheState: decoded.cacheState,
            deliveryPath: decoded.deliveryPath,
            localPathExposed: true,
            expiresAt: decoded.expiresAt
        )

        XCTAssertThrowsError(try invalid.validated()) { error in
            XCTAssertEqual(error as? SharedContractValidationError, .localPathExposed)
        }
    }

    private func fixtureData(named name: String) throws -> Data {
        let bundle = Bundle(for: SharedContractConformanceTests.self)
        let filename = (name as NSString).deletingPathExtension
        let extensionName = (name as NSString).pathExtension
        let candidates = [
            bundle.url(forResource: filename, withExtension: extensionName),
            bundle.url(
                forResource: filename,
                withExtension: extensionName,
                subdirectory: "golden"
            ),
        ]
        guard let fixture = candidates.compactMap({ candidate in candidate }).first else {
            XCTFail("Missing bundled shared-contract fixture: \(name)")
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: fixture, options: [.mappedIfSafe])
    }

    private func canonicalJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { byte in String(format: "%02x", byte) }
            .joined()
    }

    private enum FixtureError: LocalizedError {
        case missing(String)

        var errorDescription: String? {
            switch self {
            case let .missing(name):
                "The canonical shared-contract fixture \(name) was not bundled into the test target."
            }
        }
    }
}
