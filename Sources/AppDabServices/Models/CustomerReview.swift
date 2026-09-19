import BagbutikAppStoreModels
import Foundation

public struct CustomerReview: Codable, Equatable, Hashable, Sendable {
    public let reviewID: String
    public let title: String
    public let body: String
    public let createdDate: Date
    public let rating: Int
    public let reviewerNickname: String
    public let territory: String
    public let response: CustomerReviewResponse?

    public init(
        reviewID: String,
        title: String,
        body: String,
        createdDate: Date,
        rating: Int,
        reviewerNickname: String,
        territory: String,
        response: CustomerReviewResponse?
    ) {
        self.reviewID = reviewID
        self.title = title
        self.body = body
        self.createdDate = createdDate
        self.rating = rating
        self.reviewerNickname = reviewerNickname
        self.territory = territory
        self.response = response
    }

    init(customerReview: BagbutikAppStoreModels.CustomerReview, response: CustomerReviewResponseV1?) {
        self.init(
            reviewID: customerReview.id,
            title: customerReview.attributes?.title ?? "",
            body: customerReview.attributes?.body ?? "",
            createdDate: customerReview.attributes?.createdDate ?? .distantPast,
            rating: customerReview.attributes?.rating ?? 0,
            reviewerNickname: customerReview.attributes?.reviewerNickname ?? "",
            territory: (customerReview.attributes?.territory ?? .usa).rawValue,
            response: response.map(CustomerReviewResponse.init(response:))
        )
    }
}
