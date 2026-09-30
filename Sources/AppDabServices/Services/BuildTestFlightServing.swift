public protocol BuildTestFlightServing: Sendable {
    func getBetaBuildLocalization(accountID: String, localizationID: String) async throws -> BetaBuildLocalizationSummary
    func updateBetaBuildLocalization(accountID: String, localizationID: String, whatsNew: String) async throws -> BetaBuildLocalizationSummary
    func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot
    func mutateBuild(
        accountID: String,
        buildID: String,
        mutation: BuildTestFlightMutation,
    ) async throws -> BuildSummary
}
