public protocol BetaGroupTesterServing: Sendable {
    func membership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership
    func mutate(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership
}
