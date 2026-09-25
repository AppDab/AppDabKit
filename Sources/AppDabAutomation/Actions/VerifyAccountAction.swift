import AppDabServices

public struct VerifyAccountAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .verifyAccount,
        title: "Verify Account",
        description: "Verify a configured App Store Connect API key.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier.")
        ], required: ["accountID"]),
        outputSchema: Schema.object(properties: [
            "account": .object(["type": .string("object")]),
            "issue": .object(["type": .string("object")]),
        ], required: ["account"]),
        outputType: "account_verification",
        supportedSurfaces: [.mcp, .cli, .appIntents],
        safety: .read
    )

    public init() {}

    public func perform(
        input: VerifyAccountInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AccountVerification {
        try await dataProvider.verifyAccount(accountID: input.accountID)
    }

    public func summary(for output: AccountVerification) -> String {
        if output.issue == nil {
            "API key for \(output.account.name) is valid."
        } else {
            "API key for \(output.account.name) is valid with an App Store Connect agreement warning."
        }
    }

    public func data(for output: AccountVerification) throws -> JSONValue {
        var data: [String: JSONValue] = [
            "account": try JSONValue.fromEncodable(output.account)
        ]
        if let issue = output.issue {
            data["issue"] = try JSONValue.fromEncodable(issue)
        }
        return .object(data)
    }
}
