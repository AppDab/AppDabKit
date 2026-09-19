public protocol ServiceProviding: Sendable {
    var accountProvider: any AccountProviding { get }
    var appCatalogService: any AppCatalogServing { get }
    var customerReviewService: any CustomerReviewServing { get }
}
