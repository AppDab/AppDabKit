public protocol BetaGroupTesterServing: Sendable {
    func listBetaTesters(accountID: String, scope: BetaTesterScope, pagination: PaginationRequest) async throws -> BetaTesterList
    func inviteBetaTester(accountID: String, email: String, firstName: String?, lastName: String?, destination: BetaTesterDestination) async throws -> BetaTesterSummary
    func sendBetaTesterInvitation(accountID: String, appID: String, testerID: String) async throws -> BetaTesterSummary
    func membership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership
    func mutate(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership
}
