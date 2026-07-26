import CryptoKit
import Foundation
import XCTest
@testable import CinaVaultIOS

final class SharedContractConformanceTests: XCTestCase {
    func testMetadataProviderGoldenFileHashAndRoundTrip() throws {
        let data = try fixtureData(named: "metadata-provider-registry.json")
        XCTAssertEqual(sha256(data), metadataProviderFixtureSHA256)

        let decoded = try JSONDecoder().decode(MetadataProviderRegistryContract.self, from: data)
        try decoded.validated()

        let encoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try canonicalJSON(encoded), try canonicalJSON(data))
        XCTAssertEqual(decoded.providers.map(\.id), ["tvmaze", "tmdb"])
        XCTAssertTrue(decoded.providers.allSatisfy(\.enabled))
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
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixture = repositoryRoot
            .appendingPathComponent("contracts", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("golden", isDirectory: true)
            .appendingPathComponent(name)
        return try Data(contentsOf: fixture)
    }

    private func canonicalJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
