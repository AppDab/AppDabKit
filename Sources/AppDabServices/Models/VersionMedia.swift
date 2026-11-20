import CryptoKit
import Foundation

public enum VersionMediaKind: String, Codable, Equatable, Sendable {
    case screenshot, appPreview
}

public struct VersionMediaScope: Codable, Equatable, Sendable {
    public let accountID: String
    public let versionID: String
    public let locale: String
    public let kind: VersionMediaKind

    public init(accountID: String, versionID: String, locale: String, kind: VersionMediaKind) {
        self.accountID = accountID
        self.versionID = versionID
        self.locale = locale
        self.kind = kind
    }
}

public struct VersionMediaPlacement: Codable, Equatable, Sendable {
    public let id: String
    public let assetID: String
    public let placementGroup: String
    public let fileName: String
    public let fileSize: Int?
    public let assetState: String
    public let placementState: String
    public let stateDetails: [JSONValue]

    public init(id: String, assetID: String, placementGroup: String, fileName: String, fileSize: Int? = nil, assetState: String, placementState: String, stateDetails: [JSONValue] = []) {
        self.id = id
        self.assetID = assetID
        self.placementGroup = placementGroup
        self.fileName = fileName
        self.fileSize = fileSize
        self.assetState = assetState
        self.placementState = placementState
        self.stateDetails = stateDetails
    }
}

public struct VersionMediaRequirement: Codable, Equatable, Sendable {
    public let placementGroup: String
    public let specs: [JSONValue]
    public let maximumCount: Int?

    public init(placementGroup: String, specs: [JSONValue] = [], maximumCount: Int? = nil) {
        self.placementGroup = placementGroup
        self.specs = specs
        self.maximumCount = maximumCount
    }
}

public struct VersionMediaList: Codable, Equatable, Sendable {
    public let appID: String
    public let localizationID: String
    public let placements: [VersionMediaPlacement]
    public let requirements: [VersionMediaRequirement]

    public init(appID: String, localizationID: String, placements: [VersionMediaPlacement], requirements: [VersionMediaRequirement]) {
        self.appID = appID
        self.localizationID = localizationID
        self.placements = placements
        self.requirements = requirements
    }
}

public struct MediaFileFingerprint: Codable, Equatable, Sendable {
    public let size: Int
    public let sha256: String

    public static func read(path: String) throws -> Self {
        let url = URL(fileURLWithPath: path)
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw ServiceError.invalidArguments("The media file must be a regular file.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        var size = 0
        while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty {
            hash.update(data: bytes)
            size += bytes.count
        }
        return .init(size: size, sha256: hash.finalize().map { String(format: "%02x", $0) }.joined())
    }
}

public struct VersionMediaUpload: Codable, Equatable, Sendable {
    public static func validateFile(path: String, fingerprint: MediaFileFingerprint, requirement: VersionMediaRequirement) throws {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let compatible = requirement.specs.isEmpty || requirement.specs.contains { spec in
            let attributes = spec.objectValue ?? [:]
            let extensions: [String] = if case let .array(values) = attributes["fileExtensions"] {
                values.compactMap(\.stringValue).map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            } else {
                []
            }
            return (extensions.isEmpty || extensions.contains(ext)) && (attributes["maxFileSize"]?.intValue.map { fingerprint.size <= $0 } ?? true)
        }
        guard compatible else { throw ServiceError.invalidArguments("The file extension or size does not match Apple's specifications for \(requirement.placementGroup). Use list to inspect its media requirements.") }
    }

    public let filePath: String
    public let placementGroup: String
    public let previewFrameTimeCode: String?
    public let wait: Bool
    public let timeout: Int
    public let fingerprint: MediaFileFingerprint

    public init(filePath: String, placementGroup: String, previewFrameTimeCode: String? = nil, wait: Bool = false, timeout: Int = 300, fingerprint: MediaFileFingerprint) {
        self.filePath = filePath
        self.placementGroup = placementGroup
        self.previewFrameTimeCode = previewFrameTimeCode
        self.wait = wait
        self.timeout = timeout
        self.fingerprint = fingerprint
    }
}

public struct VersionMediaResult: Codable, Equatable, Sendable {
    public let placements: [VersionMediaPlacement]
    public let assetID: String?
    public let uploadComplete: Bool?
    public let destinationPath: String?
    public let fingerprint: MediaFileFingerprint?

    public init(placements: [VersionMediaPlacement] = [], assetID: String? = nil, uploadComplete: Bool? = nil, destinationPath: String? = nil, fingerprint: MediaFileFingerprint? = nil) {
        self.placements = placements
        self.assetID = assetID
        self.uploadComplete = uploadComplete
        self.destinationPath = destinationPath
        self.fingerprint = fingerprint
    }

    public func validateDownloadedFile() throws {
        guard let destinationPath else { return }
        guard let fingerprint else { throw ServiceError.invalidArguments("The download receipt is missing its file fingerprint.") }
        guard try MediaFileFingerprint.read(path: destinationPath) == fingerprint else {
            throw ServiceError.invalidArguments("The downloaded file has changed since this operation completed.")
        }
    }
}
