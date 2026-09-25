import AppDabServices

public struct ServiceAutomationDataProvider: AutomationDataProviding {
    private let services: any ServiceProviding
    private let storedAccounts: any AutomationAccountStoring

    public init(services: any ServiceProviding, accountStore: any AutomationAccountStoring) {
        self.services = services
        storedAccounts = accountStore
    }

    public func accountStore() throws -> any AutomationAccountStoring { storedAccounts }

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

    public func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppDabServices.AppVersion {
        try await services.appCatalogService.createAppVersion(
            accountID: accountID,
            appID: appID,
            platform: platform,
            version: version
        )
    }

    public func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        try await services.customerReviewService.listCustomerReviews(accountID: accountID, appID: appID, pagination: pagination)
    }

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        try await services.customerReviewService.getCustomerReview(accountID: accountID, reviewID: reviewID)
    }
}
