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
    func getBetaBuildLocalization(accountID: String, localizationID: String) async throws -> BetaBuildLocalizationSummary
    func updateBetaBuildLocalization(accountID: String, localizationID: String, whatsNew: String) async throws -> BetaBuildLocalizationSummary
    func betaGroupTesterMembership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership
    func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership
    func listBetaTesters(accountID: String, scope: BetaTesterScope, pagination: PaginationRequest) async throws -> BetaTesterList
    func inviteBetaTester(accountID: String, email: String, firstName: String?, lastName: String?, destination: BetaTesterDestination) async throws -> BetaTesterSummary
    func sendBetaTesterInvitation(accountID: String, appID: String, testerID: String) async throws -> BetaTesterSummary
    func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList
    func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary
    func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary
    func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary
    func deleteBetaGroup(accountID: String, betaGroupID: String) async throws
    func betaGroupExists(accountID: String, betaGroupID: String) async throws -> Bool
    func betaGroupBuildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership
    func mutateBetaGroupBuild(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership
    func listBetaAppLocalizations(accountID: String, appID: String) async throws -> [BetaAppLocalizationSummary]
    func getBetaAppLocalization(accountID: String, localizationID: String) async throws -> BetaAppLocalizationSummary
    func createBetaAppLocalization(accountID: String, appID: String, locale: String) async throws -> BetaAppLocalizationSummary
    func updateBetaAppLocalization(accountID: String, localizationID: String, changes: BetaAppLocalizationChanges) async throws -> BetaAppLocalizationSummary
    func deleteBetaAppLocalization(accountID: String, localizationID: String) async throws
    func getBetaAppReviewDetail(accountID: String, appID: String) async throws -> BetaAppReviewDetailSummary
    func updateBetaAppReviewDetail(accountID: String, appID: String, changes: BetaAppReviewDetailChanges) async throws -> BetaAppReviewDetailSummary
    func getBetaLicenseAgreement(accountID: String, appID: String) async throws -> BetaLicenseAgreementSummary
    func updateBetaLicenseAgreement(accountID: String, agreementID: String, agreementText: String) async throws -> BetaLicenseAgreementSummary
    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String,
    ) async throws -> AppVersion
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList
}

public extension AutomationDataProviding {
    func listBetaGroups(accountID _: String, appID _: String, pagination _: PaginationRequest) async throws -> BetaGroupList {
        throw ServiceError.upstream("Beta groups are unavailable for this data provider.")
    }

    func getBetaGroup(accountID _: String, betaGroupID _: String) async throws -> BetaGroupSummary {
        throw ServiceError.upstream("Beta groups are unavailable for this data provider.")
    }

    func createBetaGroup(accountID _: String, appID _: String, name _: String, isInternalGroup _: Bool, hasAccessToAllBuilds _: Bool?) async throws -> BetaGroupSummary {
        throw ServiceError.upstream("Beta group creation is unavailable for this data provider.")
    }

    func updateBetaGroup(accountID _: String, betaGroupID _: String, changes _: BetaGroupChanges) async throws -> BetaGroupSummary {
        throw ServiceError.upstream("Beta group updates are unavailable for this data provider.")
    }

    func deleteBetaGroup(accountID _: String, betaGroupID _: String) async throws {
        throw ServiceError.upstream("Beta group deletion is unavailable for this data provider.")
    }

    func betaGroupExists(accountID _: String, betaGroupID _: String) async throws -> Bool {
        throw ServiceError.upstream("Beta group lookup is unavailable for this data provider.")
    }

    func betaGroupBuildMembership(accountID _: String, betaGroupID _: String, buildID _: String) async throws -> BetaGroupBuildMembership {
        throw ServiceError.upstream("Beta group build state is unavailable for this data provider.")
    }

    func mutateBetaGroupBuild(accountID _: String, betaGroupID _: String, buildID _: String, add _: Bool) async throws -> BetaGroupBuildMembership {
        throw ServiceError.upstream("Beta group build mutations are unavailable for this data provider.")
    }

    func listBetaAppLocalizations(accountID _: String, appID _: String) async throws -> [BetaAppLocalizationSummary] {
        throw ServiceError.upstream("Beta app localizations are unavailable for this data provider.")
    }

    func getBetaAppLocalization(accountID _: String, localizationID _: String) async throws -> BetaAppLocalizationSummary {
        throw ServiceError.upstream("Beta app localizations are unavailable for this data provider.")
    }

    func createBetaAppLocalization(accountID _: String, appID _: String, locale _: String) async throws -> BetaAppLocalizationSummary {
        throw ServiceError.upstream("Beta app localization creation is unavailable for this data provider.")
    }

    func updateBetaAppLocalization(accountID _: String, localizationID _: String, changes _: BetaAppLocalizationChanges) async throws -> BetaAppLocalizationSummary {
        throw ServiceError.upstream("Beta app localization updates are unavailable for this data provider.")
    }

    func deleteBetaAppLocalization(accountID _: String, localizationID _: String) async throws {
        throw ServiceError.upstream("Beta app localization deletion is unavailable for this data provider.")
    }

    func getBetaAppReviewDetail(accountID _: String, appID _: String) async throws -> BetaAppReviewDetailSummary {
        throw ServiceError.upstream("Beta app review details are unavailable for this data provider.")
    }

    func updateBetaAppReviewDetail(accountID _: String, appID _: String, changes _: BetaAppReviewDetailChanges) async throws -> BetaAppReviewDetailSummary {
        throw ServiceError.upstream("Beta app review detail updates are unavailable for this data provider.")
    }

    func getBetaLicenseAgreement(accountID _: String, appID _: String) async throws -> BetaLicenseAgreementSummary {
        throw ServiceError.upstream("Beta license agreements are unavailable for this data provider.")
    }

    func updateBetaLicenseAgreement(accountID _: String, agreementID _: String, agreementText _: String) async throws -> BetaLicenseAgreementSummary {
        throw ServiceError.upstream("Beta license agreement updates are unavailable for this data provider.")
    }

    func buildSnapshot(accountID _: String, buildID _: String, scope _: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        throw ServiceError.upstream("Build TestFlight state is unavailable for this data provider.")
    }

    func mutateBuild(accountID _: String, buildID _: String, mutation _: BuildTestFlightMutation) async throws -> BuildSummary {
        throw ServiceError.upstream("Build TestFlight mutations are unavailable for this data provider.")
    }

    func getBetaBuildLocalization(accountID _: String, localizationID _: String) async throws -> BetaBuildLocalizationSummary {
        throw ServiceError.upstream("Build TestFlight localization is unavailable for this data provider.")
    }

    func updateBetaBuildLocalization(accountID _: String, localizationID _: String, whatsNew _: String) async throws -> BetaBuildLocalizationSummary {
        throw ServiceError.upstream("Build TestFlight localization updates are unavailable for this data provider.")
    }

    func betaGroupTesterMembership(accountID _: String, betaGroupID _: String, testerID _: String) async throws -> BetaGroupTesterMembership {
        throw ServiceError.upstream("Beta group tester state is unavailable for this data provider.")
    }

    func mutateBetaGroupTester(accountID _: String, betaGroupID _: String, mutation _: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        throw ServiceError.upstream("Beta group tester mutations are unavailable for this data provider.")
    }

    func listBetaTesters(accountID _: String, scope _: BetaTesterScope, pagination _: PaginationRequest) async throws -> BetaTesterList {
        throw ServiceError.upstream("Beta tester listing is unavailable for this data provider.")
    }

    func inviteBetaTester(accountID _: String, email _: String, firstName _: String?, lastName _: String?, destination _: BetaTesterDestination) async throws -> BetaTesterSummary {
        throw ServiceError.upstream("Beta tester invitations are unavailable for this data provider.")
    }

    func sendBetaTesterInvitation(accountID _: String, appID _: String, testerID _: String) async throws -> BetaTesterSummary {
        throw ServiceError.upstream("Beta tester invitations are unavailable for this data provider.")
    }
}
