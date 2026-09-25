public struct AppVersionList: Codable, Equatable, Sendable {
    public let appID: String
    public let versions: [AppVersion]
    public let pagination: PaginationMetadata

    public init(appID: String, versions: [AppVersion], pagination: PaginationMetadata) {
        self.appID = appID
        self.versions = versions
        self.pagination = pagination
    }
}
