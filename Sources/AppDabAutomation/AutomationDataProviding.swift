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
    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList
}
