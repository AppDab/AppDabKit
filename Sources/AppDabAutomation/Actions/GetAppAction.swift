import AppDabServices

public struct GetAppAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getApp,
        title: "Get App",
        description: "Fetch a specific app and its version details for a configured App Store Connect account.",
        inputSchema: Schema.object(
            properties: [
                "accountID": Schema.string(description: "The AppDab account identifier."),
                "appID": Schema.string(description: "The App Store Connect app identifier.")
            ],
            required: ["accountID", "appID"]
        ),
        outputSchema: Schema.object(properties: [
            "app": .object(["type": .string("object")])
        ], required: ["app"]),
        outputType: "app",
        supportedSurfaces: [.mcp, .cli, .appIntents],
        safety: .read
    )

    public init() {}

    public func perform(
        input: GetAppInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AppDetail {
        try await dataProvider.getApp(accountID: input.accountID, appID: input.appID)
    }

    public func summary(for output: AppDetail) -> String {
        AutomationActionSummary.fetchedApp(name: output.name)
    }

    public func data(for output: AppDetail) throws -> JSONValue {
        .object(["app": try JSONValue.fromEncodable(output)])
    }
}
