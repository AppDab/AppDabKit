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
    /// The legacy version field holds the build number.
    public var buildNumber: String {
        version
    }

    public let prereleaseVersion: String?
    public let iconURL: URL?
    public let externalBetaState: String?
    public let testFlight: TestFlightBuildDetail?

    public init(
        buildID: String,
        version: String,
        platform: String?,
        processingState: String?,
        uploadedDate: Date?,
        expirationDate: Date?,
        expired: Bool?,
        prereleaseVersion: String? = nil,
        iconURL: URL? = nil,
        externalBetaState: String? = nil,
        testFlight: TestFlightBuildDetail? = nil,
    ) {
        self.buildID = buildID
        self.version = version
        self.platform = platform
        self.processingState = processingState
        self.uploadedDate = uploadedDate
        self.expirationDate = expirationDate
        self.expired = expired
        self.prereleaseVersion = prereleaseVersion
        self.iconURL = iconURL
        self.externalBetaState = externalBetaState
        self.testFlight = testFlight
    }

    init(
        build: Build, platform: String?, prereleaseVersion: String? = nil,
        externalBetaState: String? = nil, testFlight: TestFlightBuildDetail? = nil,
    ) {
        self.init(
            buildID: build.id,
            version: build.attributes?.version ?? "",
            platform: platform,
            processingState: build.attributes?.processingState?.rawValue,
            uploadedDate: build.attributes?.uploadedDate,
            expirationDate: build.attributes?.expirationDate,
            expired: build.attributes?.expired,
            prereleaseVersion: prereleaseVersion,
            iconURL: build.attributes?.iconAssetToken?.url,
            externalBetaState: externalBetaState,
            testFlight: testFlight,
        )
    }
}
