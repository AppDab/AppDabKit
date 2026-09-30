import AppDabServices

public struct GetBuildAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getBuild,
        title: "Get Build",
        description: "Fetch one authoritative build by identifier.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "buildID": Schema.string(description: "The App Store Connect build identifier."),
        ], required: ["accountID", "buildID"]),
        outputSchema: Schema.object(properties: [
            "build": Schema.buildSummaryOutput,
        ], required: ["build"]),
        outputType: "build",
        safety: .read,
    )

    public init() {}

    public func perform(input: GetBuildInput, dataProvider: any AutomationDataProviding) async throws -> BuildSummary {
        try await dataProvider.getBuild(accountID: input.accountID, buildID: input.buildID)
    }

    public func summary(for output: BuildSummary) -> String {
        "Fetched build \(output.version)."
    }

    public func data(for output: BuildSummary) throws -> JSONValue {
        try .object(["build": JSONValue.fromEncodable(output)])
    }
}
