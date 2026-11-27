import AppDabServices

public struct GetTestFlightBuildAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getTestFlightBuild,
        title: "Get TestFlight Build",
        description: "Fetch a TestFlight build with What to Test localizations and bundle metadata.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "buildID": Schema.string(description: "The App Store Connect build identifier."),
        ], required: ["accountID", "appID", "buildID"]),
        outputSchema: Schema.testFlightBuildDetailOutput,
        outputType: "testFlightBuild",
        safety: .read,
    )

    public init() {}

    public func perform(input: GetTestFlightBuildInput, dataProvider: any AutomationDataProviding) async throws -> TestFlightBuildDetail {
        try await dataProvider.testFlightBuilds().getBuild(accountID: input.accountID, appID: input.appID, buildID: input.buildID)
    }

    public func summary(for output: TestFlightBuildDetail) -> String {
        "Fetched build \(output.build.id)."
    }

    public func data(for output: TestFlightBuildDetail) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
