public protocol ServiceProviding: Sendable {
    var accountProvider: any AccountProviding { get }
    var appCatalogService: any AppCatalogServing { get }
    var buildService: any BuildServing { get }
    var buildTestFlightService: any BuildTestFlightServing { get }
    var customerReviewService: any CustomerReviewServing { get }
}
