import AppDabServices

public struct GetCustomerReviewAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getCustomerReview,
        title: "Get Customer Review",
        description: "Fetch a customer review and any published response for a configured App Store Connect account.",
        inputSchema: Schema.object(
            properties: [
                "accountID": Schema.string(description: "The AppDab account identifier."),
                "reviewID": Schema.string(description: "The App Store Connect customer review identifier.")
            ],
            required: ["accountID", "reviewID"]
        ),
        outputSchema: Schema.object(properties: [
            "review": .object(["type": .string("object")])
        ], required: ["review"]),
        outputType: "customer_review",
        safety: .read
    )

    public init() {}

    public func perform(
        input: GetCustomerReviewInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> CustomerReview {
        try await dataProvider.getCustomerReview(accountID: input.accountID, reviewID: input.reviewID)
    }

    public func summary(for output: CustomerReview) -> String {
        AutomationActionSummary.fetchedReview(title: output.title)
    }

    public func data(for output: CustomerReview) throws -> JSONValue {
        .object(["review": try JSONValue.fromEncodable(output)])
    }
}
