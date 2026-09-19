public protocol AppCatalogServing: Sendable {
    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList
    func getApp(accountID: String, appID: String) async throws -> AppDetail
    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion
}
