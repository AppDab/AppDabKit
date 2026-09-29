import AppDabServices

public protocol AutomationDataProviding: Sendable {
    func accountStore() throws -> any AutomationAccountStoring
    func listAccounts() async throws -> [AccountSummary]
    func verifyAccount(accountID: String) async throws -> AccountVerification
    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList
    func getApp(accountID: String, appID: String) async throws -> AppDetail
    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview
    func listAppVersions(accountID: String, appID: String, filter: AppVersionFilter, pagination: PaginationRequest) async throws -> AppVersionList
    func getAppVersion(accountID: String, appID: String, versionID: String) async throws -> AppVersion
    func listBuilds(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BuildList
    func getBuild(accountID: String, buildID: String) async throws -> BuildSummary
    func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot
    func mutateBuild(accountID: String, buildID: String, mutation: BuildTestFlightMutation) async throws -> BuildSummary
    func betaGroupTesterMembership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership
    func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership
    func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList
    func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary
    func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary
    func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary
    func betaGroupBuildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership
    func mutateBetaGroupBuild(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership
    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList
}

public extension AutomationDataProviding {
    func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList { throw ServiceError.upstream("Beta groups are unavailable for this data provider.") }
    func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary { throw ServiceError.upstream("Beta groups are unavailable for this data provider.") }
    func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary { throw ServiceError.upstream("Beta group creation is unavailable for this data provider.") }
    func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary { throw ServiceError.upstream("Beta group updates are unavailable for this data provider.") }
    func betaGroupBuildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership { throw ServiceError.upstream("Beta group build state is unavailable for this data provider.") }
    func mutateBetaGroupBuild(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership { throw ServiceError.upstream("Beta group build mutations are unavailable for this data provider.") }
    func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        throw ServiceError.upstream("Build TestFlight state is unavailable for this data provider.")
    }

    func mutateBuild(accountID: String, buildID: String, mutation: BuildTestFlightMutation) async throws -> BuildSummary {
        throw ServiceError.upstream("Build TestFlight mutations are unavailable for this data provider.")
    }

    func betaGroupTesterMembership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership {
        throw ServiceError.upstream("Beta group tester state is unavailable for this data provider.")
    }

    func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        throw ServiceError.upstream("Beta group tester mutations are unavailable for this data provider.")
    }
}
