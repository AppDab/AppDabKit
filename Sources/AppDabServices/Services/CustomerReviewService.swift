import BagbutikCore
import BagbutikAppStore
import BagbutikAppStoreModels
import ConnectAccounts
import Foundation

public final class CustomerReviewService: CustomerReviewServing, @unchecked Sendable {
    public typealias ListReviewsHandler = @Sendable (APIKey, String, PaginationRequest) async throws -> ReviewList
    public typealias GetReviewHandler = @Sendable (APIKey, String) async throws -> CustomerReview

    private let accountProvider: any APIKeyProviding
    private let listReviewsHandler: ListReviewsHandler
    private let getReviewHandler: GetReviewHandler

    public init(
        accountProvider: any APIKeyProviding,
        listReviewsHandler: ListReviewsHandler? = nil,
        getReviewHandler: GetReviewHandler? = nil
    ) {
        self.accountProvider = accountProvider
        self.listReviewsHandler = listReviewsHandler ?? Self.listReviewsLive
        self.getReviewHandler = getReviewHandler ?? Self.getReviewLive
    }

    public func listCustomerReviews(
        accountID: String,
        appID: String,
        pagination: PaginationRequest = .init()
    ) async throws -> ReviewList {
        try pagination.validate()
        return try await fetchReviews(accountID: accountID, appID: appID, pagination: pagination)
    }

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        let apiKey = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            return try await getReviewHandler(apiKey, reviewID)
        } catch {
            throw Self.mapUpstream(error)
        }
    }

    private func fetchReviews(
        accountID: String,
        appID: String,
        pagination: PaginationRequest
    ) async throws -> ReviewList {
        let apiKey = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            return try await listReviewsHandler(apiKey, appID, pagination)
        } catch {
            throw Self.mapUpstream(error)
        }
    }

    private static func listReviewsLive(
        apiKey: APIKey,
        appID: String,
        pagination: PaginationRequest
    ) async throws -> ReviewList {
        let limit = try pagination.resolvedLimit()
        let service = BagbutikService(jwt: apiKey.jwt)
        let response: CustomerReviewsResponse
        response = try await service.request(
            reviewsRequest(appID: appID, limit: limit, cursor: try pagination.validatedCursor())
        )
        let nextCursor = try PaginationCursor.extract(from: response.links.next)
        let metadata = try paginationMetadata(
            limit: limit,
            total: response.meta?.paging.total,
            nextCursor: nextCursor
        )
        return .init(
            appID: appID,
            reviews: response.data.map { review in
                CustomerReview(customerReview: review, response: response.getResponse(for: review))
            },
            pagination: metadata
        )
    }

    static func paginationMetadata(
        limit: Int,
        total: Int?,
        nextCursor: String?
    ) throws -> PaginationMetadata {
        guard let total else {
            throw ServiceError.upstream("App Store Connect did not provide a paging total.")
        }
        return .init(limit: limit, total: total, nextCursor: nextCursor)
    }

    private static func reviewsRequest(
        appID: String,
        limit: Int,
        cursor: String?
    ) -> Request<CustomerReviewsResponse, ErrorResponse> {
        let request: Request<CustomerReviewsResponse, ErrorResponse> = .listCustomerReviewsForAppV1(
            id: appID,
            includes: [.response],
            sorts: [.createdDateDescending],
            limit: limit
        )
        return request.withPaginationCursor(cursor)
    }

    private static func getReviewLive(apiKey: APIKey, reviewID: String) async throws -> CustomerReview {
        let service = BagbutikService(jwt: apiKey.jwt)
        let response = try await service.request(.getCustomerReviewV1(id: reviewID, includes: [.response]))
        return .init(customerReview: response.data, response: response.getResponse())
    }

    private static func mapUpstream(_ error: Error) -> ServiceError {
        ServiceError.classify(error)
    }
}
