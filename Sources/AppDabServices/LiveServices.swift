/// The live App Store Connect service implementations used by AppDabKit.
///
/// Create an instance with an account provider to use the Bagbutik backed
/// services, or inject service implementations with the full initializer.
public struct LiveServices: ServiceProviding {
    public let accountProvider: any AccountProviding
    public let appCatalogService: any AppCatalogServing
    public let buildService: any BuildServing
    public let buildExportComplianceService: any BuildExportComplianceServing
    public let buildTestFlightService: any BuildTestFlightServing
    public let betaGroupTesterService: any BetaGroupTesterServing
    public let betaGroupService: any BetaGroupServing
    public let betaAppTestingService: any BetaAppTestingServing
    public let customerReviewService: any CustomerReviewServing

    /// Creates the live services using an account provider that also supplies API keys.
    public init(accountProvider: some AccountProviding & APIKeyProviding) {
        self.accountProvider = accountProvider
        appCatalogService = AppCatalogService(accountProvider: accountProvider)
        buildService = BuildService(accountProvider: accountProvider)
        buildExportComplianceService = BuildExportComplianceService(accountProvider: accountProvider)
        buildTestFlightService = BuildTestFlightService(accountProvider: accountProvider)
        betaGroupTesterService = BetaGroupTesterService(accountProvider: accountProvider)
        betaGroupService = BetaGroupService(accountProvider: accountProvider)
        betaAppTestingService = BetaAppTestingService(accountProvider: accountProvider)
        customerReviewService = CustomerReviewService(accountProvider: accountProvider)
    }

    /// Creates the service collection from explicit service implementations.
    ///
    /// Use this initializer to inject test doubles or alternate implementations.
    public init(
        accountProvider: any AccountProviding,
        appCatalogService: any AppCatalogServing,
        buildService: any BuildServing,
        buildExportComplianceService: any BuildExportComplianceServing,
        buildTestFlightService: any BuildTestFlightServing,
        betaGroupTesterService: any BetaGroupTesterServing,
        betaGroupService: any BetaGroupServing,
        betaAppTestingService: any BetaAppTestingServing,
        customerReviewService: any CustomerReviewServing,
    ) {
        self.accountProvider = accountProvider
        self.appCatalogService = appCatalogService
        self.buildService = buildService
        self.buildExportComplianceService = buildExportComplianceService
        self.buildTestFlightService = buildTestFlightService
        self.betaGroupTesterService = betaGroupTesterService
        self.betaGroupService = betaGroupService
        self.betaAppTestingService = betaAppTestingService
        self.customerReviewService = customerReviewService
    }
}
