public struct LiveServices: ServiceProviding {
    public let accountProvider: any AccountProviding
    public let appCatalogService: any AppCatalogServing
    public let buildService: any BuildServing
    public let buildTestFlightService: any BuildTestFlightServing
    public let betaGroupTesterService: any BetaGroupTesterServing
    public let customerReviewService: any CustomerReviewServing

    public init<AccountProvider>(accountProvider: AccountProvider) where AccountProvider: AccountProviding & APIKeyProviding {
        self.accountProvider = accountProvider
        self.appCatalogService = AppCatalogService(accountProvider: accountProvider)
        self.buildService = BuildService(accountProvider: accountProvider)
        self.buildTestFlightService = BuildTestFlightService(accountProvider: accountProvider)
        self.betaGroupTesterService = BetaGroupTesterService(accountProvider: accountProvider)
        self.customerReviewService = CustomerReviewService(accountProvider: accountProvider)
    }

    public init(
        accountProvider: any AccountProviding,
        appCatalogService: any AppCatalogServing,
        buildService: any BuildServing,
        buildTestFlightService: any BuildTestFlightServing,
        betaGroupTesterService: any BetaGroupTesterServing,
        customerReviewService: any CustomerReviewServing
    ) {
        self.accountProvider = accountProvider
        self.appCatalogService = appCatalogService
        self.buildService = buildService
        self.buildTestFlightService = buildTestFlightService
        self.betaGroupTesterService = betaGroupTesterService
        self.customerReviewService = customerReviewService
    }
}
