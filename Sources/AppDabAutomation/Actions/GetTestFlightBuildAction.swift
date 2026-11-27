import AppDabServices

public struct GetTestFlightBuildAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getTestFlightBuild,
        title: "Get TestFlight Build",
        description: "Fetch a TestFlight build with What to Test localizations and bundle metadata.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "buildID": Schema.string(description: "The App Store Connect build identifier."),
        ], required: ["accountID", "buildID"]),
        outputSchema: Schema.testFlightBuildDetailOutput,
        outputType: "testFlightBuild",
        safety: .read,
    )

    public init() {}

    public func perform(input: GetBuildInput, dataProvider: any AutomationDataProviding) async throws -> TestFlightBuildDetail {
        try await dataProvider.testFlightBuilds().getBuild(accountID: input.accountID, buildID: input.buildID)
    }

    public func summary(for output: TestFlightBuildDetail) -> String {
        "Fetched build \(output.build.id)."
    }

    public func data(for output: TestFlightBuildDetail) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
