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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case enabled
        case requiresKey
        case implemented
        case endpoint
        case customEndpoint
    }

    init(
        id: String,
        name: String,
        category: String,
        enabled: Bool,
        requiresKey: Bool,
        implemented: Bool,
        endpoint: String?,
        customEndpoint: String?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.enabled = enabled
        self.requiresKey = requiresKey
        self.implemented = implemented
        self.endpoint = endpoint
        self.customEndpoint = customEndpoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        requiresKey = try container.decode(Bool.self, forKey: .requiresKey)
        implemented = try container.decode(Bool.self, forKey: .implemented)
        endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint)
        customEndpoint = try container.decodeIfPresent(String.self, forKey: .customEndpoint)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(requiresKey, forKey: .requiresKey)
        try container.encode(implemented, forKey: .implemented)
        if let endpoint {
            try container.encode(endpoint, forKey: .endpoint)
        } else {
            try container.encodeNil(forKey: .endpoint)
        }
        if let customEndpoint {
            try container.encode(customEndpoint, forKey: .customEndpoint)
        } else {
            try container.encodeNil(forKey: .customEndpoint)
        }
    }
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

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case mediaKey
        case kind
        case mimeType
        case byteLength
        case sha256
        case width
        case height
        case sourceProvider
        case cacheState
        case deliveryPath
        case localPathExposed
        case expiresAt
    }

    init(
        schemaVersion: Int,
        mediaKey: String,
        kind: String,
        mimeType: String,
        byteLength: Int64,
        sha256: String,
        width: Int,
        height: Int,
        sourceProvider: String,
        cacheState: String,
        deliveryPath: String,
        localPathExposed: Bool,
        expiresAt: String?
    ) {
        self.schemaVersion = schemaVersion
        self.mediaKey = mediaKey
        self.kind = kind
        self.mimeType = mimeType
        self.byteLength = byteLength
        self.sha256 = sha256
        self.width = width
        self.height = height
        self.sourceProvider = sourceProvider
        self.cacheState = cacheState
        self.deliveryPath = deliveryPath
        self.localPathExposed = localPathExposed
        self.expiresAt = expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        mediaKey = try container.decode(String.self, forKey: .mediaKey)
        kind = try container.decode(String.self, forKey: .kind)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        byteLength = try container.decode(Int64.self, forKey: .byteLength)
        sha256 = try container.decode(String.self, forKey: .sha256)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        sourceProvider = try container.decode(String.self, forKey: .sourceProvider)
        cacheState = try container.decode(String.self, forKey: .cacheState)
        deliveryPath = try container.decode(String.self, forKey: .deliveryPath)
        localPathExposed = try container.decode(Bool.self, forKey: .localPathExposed)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(mediaKey, forKey: .mediaKey)
        try container.encode(kind, forKey: .kind)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(byteLength, forKey: .byteLength)
        try container.encode(sha256, forKey: .sha256)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(sourceProvider, forKey: .sourceProvider)
        try container.encode(cacheState, forKey: .cacheState)
        try container.encode(deliveryPath, forKey: .deliveryPath)
        try container.encode(localPathExposed, forKey: .localPathExposed)
        if let expiresAt {
            try container.encode(expiresAt, forKey: .expiresAt)
        } else {
            try container.encodeNil(forKey: .expiresAt)
        }
    }
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
