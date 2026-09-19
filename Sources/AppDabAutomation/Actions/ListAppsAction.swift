import AppDabServices

public struct ListAppsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listApps,
        title: "List Apps",
        description: "List apps for a specific configured App Store Connect account.",
        inputSchema: Schema.object(
            properties: [
                "account_id": Schema.string(description: "The AppDab account identifier."),
                "cursor": Schema.paginationCursor,
                "limit": Schema.paginationLimit
            ],
            required: ["account_id"]
        ),
        outputSchema: Schema.object(properties: [
            "apps": .object(["type": .string("array")]),
            "pagination": Schema.paginationOutput
        ], required: ["apps", "pagination"]),
        outputType: "apps",
        supportedSurfaces: [.mcp, .cli, .appIntents],
        safety: .read
    )

    public init() {}

    public func perform(
        input: ListAppsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AppList {
        try await dataProvider.listApps(accountID: input.accountID, pagination: input.pagination)
    }

    public func summary(for output: AppList) -> String {
        AutomationActionSummary.foundApps(output.apps.count)
    }

    public func data(for output: AppList) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
