public protocol BuildTestFlightServing: Sendable {
    func buildSnapshot(accountID: String, buildID: String) async throws -> BuildTestFlightSnapshot
    func mutateBuild(
        accountID: String,
        buildID: String,
        mutation: BuildTestFlightMutation
    ) async throws -> BuildSummary
}
