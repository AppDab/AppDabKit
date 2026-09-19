@testable import AppDabServices
import BagbutikAppStoreModels
import Foundation
import Testing

struct CustomerReviewServiceTests {
    @Test func validatesReviewLimit() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
        let service = CustomerReviewService(accountProvider: provider, listReviewsHandler: { _, appID, pagination in
            .init(appID: appID, reviews: [], pagination: .init(limit: try pagination.resolvedLimit(), total: 0, nextCursor: nil))
        })

        await #expect(throws: ServiceError.invalidLimit(0)) {
            _ = try await service.listCustomerReviews(
                accountID: apiKey.id,
                appID: "123",
                pagination: .init(limit: 0)
            )
        }
    }

    @Test func mapsReviewsWithResponses() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
        let service = CustomerReviewService(
            accountProvider: provider,
            listReviewsHandler: { apiKey, appID, pagination in
                .init(appID: appID, reviews: [
                    CustomerReview(
                        reviewID: "review-1",
                        title: "Great",
                        body: "Love it",
                        createdDate: Date(timeIntervalSince1970: 100),
                        rating: 5,
                        reviewerNickname: apiKey.name,
                        territory: "USA",
                        response: CustomerReviewResponse(
                            responseID: "response-1",
                            lastModifiedDate: Date(timeIntervalSince1970: 150),
                            responseBody: "Thanks",
                            state: "published"
                        )
                    )
                ], pagination: .init(limit: try pagination.resolvedLimit(), total: 1, nextCursor: nil))
            }
        )

        let reviews = try await service.listCustomerReviews(
            accountID: apiKey.id,
            appID: "123",
            pagination: .init(limit: 1)
        )

        #expect(reviews.appID == "123")
        #expect(reviews.reviews.first?.reviewID == "review-1")
        #expect(reviews.reviews.first?.response?.responseID == "response-1")
    }

    @Test func passesRequestedCursorAndLimitToReviewPagingHandler() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
        let service = CustomerReviewService(
            accountProvider: provider,
            listReviewsHandler: { _, appID, pagination in
                #expect(pagination == .init(cursor: "cursor-1", limit: 25))
                return .init(
                    appID: appID,
                    reviews: [],
                    pagination: .init(limit: try pagination.resolvedLimit(), total: 51, nextCursor: nil)
                )
            }
        )

        let reviews = try await service.listCustomerReviews(
            accountID: apiKey.id,
            appID: "123",
            pagination: .init(cursor: "cursor-1", limit: 25)
        )

        #expect(reviews.pagination.total == 51)
        #expect(reviews.pagination.hasMore == false)
    }

    @Test func customerReviewResponseRecordUsesPrettyStateName() {
        let response = CustomerReviewResponseV1(
            id: "response-1",
            attributes: .init(
                lastModifiedDate: Date(timeIntervalSince1970: 150),
                responseBody: "Thanks",
                state: .published
            )
        )

        let record = CustomerReviewResponse(response: response)

        #expect(record.state == "Published")
    }

    @Test func rejectsAMissingAppStoreConnectPagingTotal() {
        #expect(throws: ServiceError.upstream("App Store Connect did not provide a paging total.")) {
            try CustomerReviewService.paginationMetadata(limit: 50, total: nil, nextCursor: "cursor-1")
        }
    }
}
