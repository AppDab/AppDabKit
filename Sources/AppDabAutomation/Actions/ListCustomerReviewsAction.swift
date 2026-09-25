import AppDabServices

public struct ListCustomerReviewsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listCustomerReviews,
        title: "List Customer Reviews",
        description: "List recent customer reviews for an app in a configured App Store Connect account.",
        inputSchema: Schema.object(
            properties: [
                "accountID": Schema.string(description: "The AppDab account identifier."),
                "appID": Schema.string(description: "The App Store Connect app identifier."),
                "cursor": Schema.paginationCursor,
                "limit": Schema.integer(
                    description: "Maximum reviews to return, from 1 through 200.",
                    minimum: 1,
                    maximum: PaginationRequest.maximumLimit,
                    default: PaginationRequest.defaultLimit
                )
            ],
            required: ["accountID", "appID"]
        ),
        outputSchema: Schema.object(
            properties: [
                "appID": Schema.string(description: "The App Store Connect app identifier."),
                "reviews": .object(["type": .string("array")]),
                "pagination": Schema.paginationOutput
            ],
            required: ["appID", "reviews", "pagination"]
        ),
        outputType: "customer_reviews",
        safety: .read
    )

    public init() {}

    public func perform(
        input: ListCustomerReviewsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> ReviewList {
        try await dataProvider.listCustomerReviews(
            accountID: input.accountID,
            appID: input.appID,
            pagination: input.pagination
        )
    }

    public func summary(for output: ReviewList) -> String {
        AutomationActionSummary.foundReviews(output.reviews.count)
    }

    public func data(for output: ReviewList) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
