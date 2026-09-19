import AppDabServices

public struct ListAccountsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listAccounts,
        title: "List Accounts",
        description: "List the App Store Connect accounts configured in AppDab.",
        inputSchema: Schema.object(properties: [:]),
        outputSchema: Schema.object(properties: [
            "accounts": .object(["type": .string("array")])
        ], required: ["accounts"]),
        outputType: "accounts",
        supportedSurfaces: [.mcp, .cli, .appIntents],
        safety: .read
    )

    public init() {}

    public func perform(
        input: ListAccountsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> [AccountSummary] {
        try await dataProvider.listAccounts()
    }

    public func summary(for output: [AccountSummary]) -> String {
        AutomationActionSummary.foundAccounts(output.count)
    }

    public func data(for output: [AccountSummary]) throws -> JSONValue {
        .object(["accounts": try JSONValue.fromEncodable(output)])
    }
}
