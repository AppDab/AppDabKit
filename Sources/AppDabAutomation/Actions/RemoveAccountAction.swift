import AppDabServices
import Foundation

public struct RemoveAccountAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .removeAccount,
        title: "Remove Account",
        description: "Remove an App Store Connect API key from the local AppDab Keychain.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier.")
        ], required: ["accountID"]),
        outputSchema: Schema.object(properties: [
            "account": Schema.accountSummaryOutput
        ], required: ["account"]),
        outputType: "account_removal",
        safety: .write
    )

    public static let supportsDirectWriteExecution = true

    public init() {}

    public func perform(input: RemoveAccountInput, dataProvider: any AutomationDataProviding) async throws -> AccountSummary {
        let apiKey = try await dataProvider.accountStore().removeAPIKey(accountID: input.accountID)
        return .init(accountID: apiKey.id, name: apiKey.name)
    }

    public func summary(for output: AccountSummary) -> String {
        "Removed API key \(output.name)."
    }

    public func data(for output: AccountSummary) throws -> JSONValue {
        .object(["account": try .fromEncodable(output)])
    }

}
