import AppDabServices

public struct GetAppAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getApp,
        title: "Get App",
        description: "Fetch app details and a reduced display version summary. Use list_app_versions or get_app_version for authoritative versions.",
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
