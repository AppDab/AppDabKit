public enum BuildListSort: String, Codable, CaseIterable, Sendable {
    case uploadedDate
    case version
}

public protocol BuildServing: Sendable {
    func listBuilds(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BuildList
    func listBuilds(accountID: String, appID: String, pagination: PaginationRequest, sort: BuildListSort) async throws -> BuildList
    func getBuild(accountID: String, buildID: String) async throws -> BuildSummary
}

public extension BuildServing {
    func listBuilds(accountID: String, appID: String, pagination: PaginationRequest, sort: BuildListSort) async throws -> BuildList {
        guard sort == .uploadedDate else {
            throw ServiceError.invalidArguments("This build service does not support version sorting.")
        }
        return try await listBuilds(accountID: accountID, appID: appID, pagination: pagination)
    }
}
