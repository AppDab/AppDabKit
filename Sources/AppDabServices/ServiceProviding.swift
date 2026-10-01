/// A collection of App Store Connect services and their account provider.
///
/// Implement this protocol to provide alternate service implementations to
/// consumers such as ``AppDabAutomation``.
public protocol ServiceProviding: Sendable {
    var accountProvider: any AccountProviding { get }
    var appCatalogService: any AppCatalogServing { get }
    var buildService: any BuildServing { get }
    var buildExportComplianceService: any BuildExportComplianceServing { get }
    var buildTestFlightService: any BuildTestFlightServing { get }
    var betaGroupTesterService: any BetaGroupTesterServing { get }
    var betaGroupService: any BetaGroupServing { get }
    var betaAppTestingService: any BetaAppTestingServing { get }
    var customerReviewService: any CustomerReviewServing { get }
}
