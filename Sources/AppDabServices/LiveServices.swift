public struct LiveServices: ServiceProviding {
    public let accountProvider: any AccountProviding
    public let appCatalogService: any AppCatalogServing
    public let customerReviewService: any CustomerReviewServing

    public init<AccountProvider>(accountProvider: AccountProvider) where AccountProvider: AccountProviding & APIKeyProviding {
        self.accountProvider = accountProvider
        self.appCatalogService = AppCatalogService(accountProvider: accountProvider)
        self.customerReviewService = CustomerReviewService(accountProvider: accountProvider)
    }

    public init(accountProvider: any AccountProviding, appCatalogService: any AppCatalogServing, customerReviewService: any CustomerReviewServing) {
        self.accountProvider = accountProvider
        self.appCatalogService = appCatalogService
        self.customerReviewService = customerReviewService
    }
}
