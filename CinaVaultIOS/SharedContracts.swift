import Foundation

let sharedContractVersion = 1
let metadataProviderFixtureSHA256 = "b7ca1f8748296ce7651d17dec3165ac8a37e3aca321eaf558199299b44b5820d"
let artworkCacheFixtureSHA256 = "d9b08d61cd3451278315102da031d0834db315639d49d7c16efb533ddd26e697"

struct MetadataProviderContract: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let category: String
    let enabled: Bool
    let requiresKey: Bool
    let implemented: Bool
    let endpoint: String?
    let customEndpoint: String?
}

struct MetadataProviderRegistryContract: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let policy: String
    let credentialsStorage: String
    let portableAcrossOperatingSystems: Bool
    let providers: [MetadataProviderContract]
}

struct ArtworkCacheEntryContract: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let mediaKey: String
    let kind: String
    let mimeType: String
    let byteLength: Int64
    let sha256: String
    let width: Int
    let height: Int
    let sourceProvider: String
    let cacheState: String
    let deliveryPath: String
    let localPathExposed: Bool
    let expiresAt: String?
}

protocol MetadataProviderRegistryInterface: Sendable {
    func metadataProviderContract() async throws -> MetadataProviderRegistryContract
}

protocol ArtworkCacheInterface: Sendable {
    func artworkContract(mediaKey: String, kind: String) async throws -> ArtworkCacheEntryContract
}

enum SharedContractValidationError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidProviderPolicy
    case insecureCredentialStorage
    case nonPortableRegistry
    case emptyProviderRegistry
    case disabledProvider(String)
    case duplicateProvider(String)
    case missingMediaKey
    case unsupportedArtworkKind(String)
    case invalidMimeType(String)
    case invalidByteLength(Int64)
    case invalidSHA256
    case invalidDimensions
    case localPathExposed
    case insecureDeliveryPath(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "Unsupported shared contract version: \(version)"
        case .invalidProviderPolicy:
            "Metadata provider policy must enable all providers."
        case .insecureCredentialStorage:
            "Credentials must remain in the native secure store."
        case .nonPortableRegistry:
            "Metadata provider registry must be cross-platform portable."
        case .emptyProviderRegistry:
            "Metadata provider registry cannot be empty."
        case let .disabledProvider(identifier):
            "Metadata provider \(identifier) is disabled."
        case let .duplicateProvider(identifier):
            "Metadata provider identifier \(identifier) is duplicated."
        case .missingMediaKey:
            "Artwork media key is required."
        case let .unsupportedArtworkKind(kind):
            "Unsupported artwork kind: \(kind)"
        case let .invalidMimeType(mimeType):
            "Artwork MIME type must be an image: \(mimeType)"
        case let .invalidByteLength(byteLength):
            "Artwork byte length is outside the supported range: \(byteLength)"
        case .invalidSHA256:
            "Artwork SHA-256 must be a 64-character hexadecimal value."
        case .invalidDimensions:
            "Artwork dimensions must be positive."
        case .localPathExposed:
            "Artwork contracts must not expose local filesystem paths."
        case let .insecureDeliveryPath(path):
            "Artwork delivery path must use the secured artwork API: \(path)"
        }
    }
}

extension MetadataProviderRegistryContract {
    @discardableResult
    func validated() throws -> MetadataProviderRegistryContract {
        guard schemaVersion == sharedContractVersion else {
            throw SharedContractValidationError.unsupportedVersion(schemaVersion)
        }
        guard policy == "all_providers_enabled" else {
            throw SharedContractValidationError.invalidProviderPolicy
        }
        guard credentialsStorage == "native_secure_store" else {
            throw SharedContractValidationError.insecureCredentialStorage
        }
        guard portableAcrossOperatingSystems else {
            throw SharedContractValidationError.nonPortableRegistry
        }
        guard !providers.isEmpty else {
            throw SharedContractValidationError.emptyProviderRegistry
        }

        var identifiers = Set<String>()
        for provider in providers {
            guard provider.enabled else {
                throw SharedContractValidationError.disabledProvider(provider.id)
            }
            guard identifiers.insert(provider.id).inserted else {
                throw SharedContractValidationError.duplicateProvider(provider.id)
            }
        }
        return self
    }
}

extension ArtworkCacheEntryContract {
    @discardableResult
    func validated() throws -> ArtworkCacheEntryContract {
        guard schemaVersion == sharedContractVersion else {
            throw SharedContractValidationError.unsupportedVersion(schemaVersion)
        }
        guard !mediaKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SharedContractValidationError.missingMediaKey
        }
        guard ["poster", "backdrop", "thumbnail"].contains(kind) else {
            throw SharedContractValidationError.unsupportedArtworkKind(kind)
        }
        guard mimeType.hasPrefix("image/") else {
            throw SharedContractValidationError.invalidMimeType(mimeType)
        }
        guard (1 ... 25 * 1024 * 1024).contains(byteLength) else {
            throw SharedContractValidationError.invalidByteLength(byteLength)
        }
        let hexadecimal = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard sha256.count == 64,
              sha256.unicodeScalars.allSatisfy(hexadecimal.contains) else {
            throw SharedContractValidationError.invalidSHA256
        }
        guard width > 0, height > 0 else {
            throw SharedContractValidationError.invalidDimensions
        }
        guard !localPathExposed else {
            throw SharedContractValidationError.localPathExposed
        }
        guard deliveryPath.hasPrefix("/api/artwork/") else {
            throw SharedContractValidationError.insecureDeliveryPath(deliveryPath)
        }
        return self
    }
}
