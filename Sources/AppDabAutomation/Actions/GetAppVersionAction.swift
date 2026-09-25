import AppDabServices

public struct GetAppVersionAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getAppVersion,
        title: "Get App Version",
        description: "Fetch one authoritative app version by identifier.",
        inputSchema: Schema.object(
            properties: [
                "account_id": Schema.string(description: "The AppDab account identifier."),
                "app_id": Schema.string(description: "The App Store Connect app identifier."),
                "version_id": Schema.string(description: "The App Store Connect version identifier.")
            ],
            required: ["account_id", "app_id", "version_id"]
        ),
        outputSchema: Schema.object(properties: [
            "version": .object(["type": .string("object")])
        ], required: ["version"]),
        outputType: "version",
        safety: .read
    )

    public init() {}

    public func perform(
        input: GetAppVersionInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AppVersion {
        try await dataProvider.getAppVersion(accountID: input.accountID, appID: input.appID, versionID: input.versionID)
    }

    public func summary(for output: AppVersion) -> String {
        "Fetched version \(output.version)."
    }

    public func data(for output: AppVersion) throws -> JSONValue {
        .object(["version": try JSONValue.fromEncodable(output)])
    }
}
