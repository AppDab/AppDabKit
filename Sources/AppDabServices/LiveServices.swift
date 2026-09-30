public struct LiveServices: ServiceProviding {
    public let accountProvider: any AccountProviding
    public let appCatalogService: any AppCatalogServing
    public let buildService: any BuildServing
    public let buildTestFlightService: any BuildTestFlightServing
    public let betaGroupTesterService: any BetaGroupTesterServing
    public let betaGroupService: any BetaGroupServing
    public let betaAppTestingService: any BetaAppTestingServing
    public let customerReviewService: any CustomerReviewServing

    public init(accountProvider: some AccountProviding & APIKeyProviding) {
        self.accountProvider = accountProvider
        appCatalogService = AppCatalogService(accountProvider: accountProvider)
        buildService = BuildService(accountProvider: accountProvider)
        buildTestFlightService = BuildTestFlightService(accountProvider: accountProvider)
        betaGroupTesterService = BetaGroupTesterService(accountProvider: accountProvider)
        betaGroupService = BetaGroupService(accountProvider: accountProvider)
        betaAppTestingService = BetaAppTestingService(accountProvider: accountProvider)
        customerReviewService = CustomerReviewService(accountProvider: accountProvider)
    }

    public init(
        accountProvider: any AccountProviding,
        appCatalogService: any AppCatalogServing,
        buildService: any BuildServing,
        buildTestFlightService: any BuildTestFlightServing,
        betaGroupTesterService: any BetaGroupTesterServing,
        betaGroupService: any BetaGroupServing,
        betaAppTestingService: any BetaAppTestingServing,
        customerReviewService: any CustomerReviewServing,
    ) {
        self.accountProvider = accountProvider
        self.appCatalogService = appCatalogService
        self.buildService = buildService
        self.buildTestFlightService = buildTestFlightService
        self.betaGroupTesterService = betaGroupTesterService
        self.betaGroupService = betaGroupService
        self.betaAppTestingService = betaAppTestingService
        self.customerReviewService = customerReviewService
    }
}
