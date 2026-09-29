public struct BuildList: Codable, Equatable, Sendable {
    public let appID: String
    public let builds: [BuildSummary]
    public let pagination: PaginationMetadata

    public init(appID: String, builds: [BuildSummary], pagination: PaginationMetadata) {
        self.appID = appID
        self.builds = builds
        self.pagination = pagination
    }
}
