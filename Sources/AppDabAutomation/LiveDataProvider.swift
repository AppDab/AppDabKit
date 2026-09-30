import AppDabServices

public struct ServiceAutomationDataProvider: AutomationDataProviding {
    private let services: any ServiceProviding
    private let storedAccounts: any AutomationAccountStoring

    public init(services: any ServiceProviding, accountStore: any AutomationAccountStoring) {
        self.services = services
        storedAccounts = accountStore
    }

    public func accountStore() throws -> any AutomationAccountStoring {
        storedAccounts
    }

    public func listAccounts() async throws -> [AccountSummary] {
        try await services.accountProvider.listAccounts()
    }

    public func verifyAccount(accountID: String) async throws -> AccountVerification {
        try await services.accountProvider.verifyAccount(accountID: accountID)
    }

    public func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        try await services.appCatalogService.listApps(accountID: accountID, pagination: pagination)
    }

    public func getApp(accountID: String, appID: String) async throws -> AppDetail {
        try await services.appCatalogService.getApp(accountID: accountID, appID: appID)
    }

    public func listAppVersions(accountID: String, appID: String, filter: AppVersionFilter, pagination: PaginationRequest) async throws -> AppVersionList {
        try await services.appCatalogService.listAppVersions(accountID: accountID, appID: appID, filter: filter, pagination: pagination)
    }

    public func getAppVersion(accountID: String, appID: String, versionID: String) async throws -> AppVersion {
        try await services.appCatalogService.getAppVersion(accountID: accountID, appID: appID, versionID: versionID)
    }

    public func listBuilds(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BuildList {
        try await services.buildService.listBuilds(accountID: accountID, appID: appID, pagination: pagination)
    }

    public func getBuild(accountID: String, buildID: String) async throws -> BuildSummary {
        try await services.buildService.getBuild(accountID: accountID, buildID: buildID)
    }

    public func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        try await services.buildTestFlightService.buildSnapshot(accountID: accountID, buildID: buildID, scope: scope)
    }

    public func mutateBuild(accountID: String, buildID: String, mutation: BuildTestFlightMutation) async throws -> BuildSummary {
        try await services.buildTestFlightService.mutateBuild(accountID: accountID, buildID: buildID, mutation: mutation)
    }

    public func betaGroupTesterMembership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership {
        try await services.betaGroupTesterService.membership(accountID: accountID, betaGroupID: betaGroupID, testerID: testerID)
    }

    public func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList {
        try await services.betaGroupService.listBetaGroups(accountID: accountID, appID: appID, pagination: pagination)
    }

    public func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary {
        try await services.betaGroupService.getBetaGroup(accountID: accountID, betaGroupID: betaGroupID)
    }

    public func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary {
        try await services.betaGroupService.createBetaGroup(accountID: accountID, appID: appID, name: name, isInternalGroup: isInternalGroup, hasAccessToAllBuilds: hasAccessToAllBuilds)
    }

    public func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary {
        try await services.betaGroupService.updateBetaGroup(accountID: accountID, betaGroupID: betaGroupID, changes: changes)
    }

    public func betaGroupBuildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership {
        try await services.betaGroupService.buildMembership(accountID: accountID, betaGroupID: betaGroupID, buildID: buildID)
    }

    public func mutateBetaGroupBuild(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership {
        try await services.betaGroupService.mutateBuildMembership(accountID: accountID, betaGroupID: betaGroupID, buildID: buildID, add: add)
    }

    public func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        try await services.betaGroupTesterService.mutate(accountID: accountID, betaGroupID: betaGroupID, mutation: mutation)
    }

    public func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String,
    ) async throws -> AppDabServices.AppVersion {
        try await services.appCatalogService.createAppVersion(
            accountID: accountID,
            appID: appID,
            platform: platform,
            version: version,
        )
    }

    public func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        try await services.customerReviewService.listCustomerReviews(accountID: accountID, appID: appID, pagination: pagination)
    }

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        try await services.customerReviewService.getCustomerReview(accountID: accountID, reviewID: reviewID)
    }
}
