public enum BuildListSort: String, Codable, CaseIterable, Sendable {
    case uploadedDate
    case version
}

public protocol BuildServing: Sendable {
    func listBuilds(accountID: String, appID: String, pagination: PaginationRequest, sort: BuildListSort) async throws -> BuildList
    func getBuild(accountID: String, buildID: String) async throws -> BuildSummary
}
