import AppDabServices

public struct GetTestFlightScreenshotFeedbackAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getTestFlightScreenshotFeedback,
        title: "Get TestFlight Screenshot Feedback",
        description: "Fetch a TestFlight screenshot submission and attachment metadata for an app.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "submissionID": Schema.string(description: "The App Store Connect screenshot submission identifier."),
        ], required: ["accountID", "submissionID"]),
        outputSchema: Schema.object(properties: [
            "appID": Schema.outputString, "submission": Schema.testFlightScreenshotFeedbackOutput,
        ], required: ["appID", "submission"]),
        outputType: "testFlightScreenshotFeedback",
        safety: .read,
    )

    public init() {}

    public func perform(input: GetTestFlightScreenshotFeedbackInput, dataProvider: any AutomationDataProviding) async throws -> TestFlightScreenshotFeedbackDetail {
        try await dataProvider.testFlightScreenshotFeedback().getSubmission(accountID: input.accountID, submissionID: input.submissionID)
    }

    public func summary(for output: TestFlightScreenshotFeedbackDetail) -> String {
        "Fetched screenshot feedback \(output.submission.id)."
    }

    public func data(for output: TestFlightScreenshotFeedbackDetail) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
