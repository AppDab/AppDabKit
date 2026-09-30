public protocol BetaGroupServing: Sendable {
    func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList
    func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary
    func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary
    func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary
    func deleteBetaGroup(accountID: String, betaGroupID: String) async throws
    func betaGroupExists(accountID: String, betaGroupID: String) async throws -> Bool
    func buildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership
    func mutateBuildMembership(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership
}
