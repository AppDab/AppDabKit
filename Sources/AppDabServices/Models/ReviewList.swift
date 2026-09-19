import Foundation

public struct ReviewList: Codable, Equatable, Hashable, Sendable {
    public let appID: String
    public let reviews: [CustomerReview]
    public let pagination: PaginationMetadata

    public init(
        appID: String,
        reviews: [CustomerReview],
        pagination: PaginationMetadata? = nil
    ) {
        self.appID = appID
        self.reviews = reviews
        self.pagination = pagination ?? .init(
            limit: PaginationRequest.defaultLimit,
            total: reviews.count,
            nextCursor: nil
        )
    }
}
