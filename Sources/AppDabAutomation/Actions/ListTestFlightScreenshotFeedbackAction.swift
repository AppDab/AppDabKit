import AppDabServices

public struct ListTestFlightScreenshotFeedbackAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listTestFlightScreenshotFeedback,
        title: "List TestFlight Screenshot Feedback",
        description: "List an app's TestFlight screenshot feedback, newest first. Follow pagination to read every submission.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.integer(
                description: "Maximum submissions to return, from 1 through 200.",
                minimum: 1,
                maximum: PaginationRequest.maximumLimit,
                default: PaginationRequest.defaultLimit,
            ),
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: [
            "appID": Schema.outputString,
            "submissions": Schema.array(items: Schema.testFlightScreenshotFeedbackOutput),
            "pagination": Schema.paginationOutput,
        ], required: ["appID", "submissions", "pagination"]),
        outputType: "testFlightScreenshotFeedbackList",
        safety: .read,
    )

    public init() {}

    public func perform(input: ListTestFlightScreenshotFeedbackInput, dataProvider: any AutomationDataProviding) async throws -> TestFlightScreenshotFeedbackList {
        try await dataProvider.testFlightScreenshotFeedback().listSubmissions(accountID: input.accountID, appID: input.appID, pagination: input.pagination)
    }

    public func summary(for output: TestFlightScreenshotFeedbackList) -> String {
        "Found \(output.submissions.count) submissions."
    }

    public func data(for output: TestFlightScreenshotFeedbackList) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
