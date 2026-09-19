public protocol CustomerReviewServing: Sendable {
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList
    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview
}
