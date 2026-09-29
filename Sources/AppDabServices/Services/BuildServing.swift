public protocol BuildServing: Sendable {
    func listBuilds(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BuildList
    func getBuild(accountID: String, buildID: String) async throws -> BuildSummary
}
