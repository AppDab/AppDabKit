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
    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList
}

public extension AutomationDataProviding {
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
