import BagbutikModelsShared
import Foundation

public struct BuildSummary: Codable, Equatable, Sendable {
    public let buildID: String
    public let version: String
    public let platform: String?
    public let processingState: String?
    public let uploadedDate: Date?
    public let expirationDate: Date?
    public let expired: Bool?

    public init(
        buildID: String,
        version: String,
        platform: String?,
        processingState: String?,
        uploadedDate: Date?,
        expirationDate: Date?,
        expired: Bool?
    ) {
        self.buildID = buildID
        self.version = version
        self.platform = platform
        self.processingState = processingState
        self.uploadedDate = uploadedDate
        self.expirationDate = expirationDate
        self.expired = expired
    }

    init(build: Build, platform: String?) {
        self.init(
            buildID: build.id,
            version: build.attributes?.version ?? "",
            platform: platform,
            processingState: build.attributes?.processingState?.rawValue,
            uploadedDate: build.attributes?.uploadedDate,
            expirationDate: build.attributes?.expirationDate,
            expired: build.attributes?.expired
        )
    }
}
