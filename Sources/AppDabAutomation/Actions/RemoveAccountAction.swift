import AppDabServices

public struct RemoveAccountAction: GuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .removeAccount,
        title: "Remove Account",
        description: "Remove an App Store Connect API key from the local AppDab Keychain.",
        inputSchema: Schema.object(properties: [
            "account_id": Schema.string(description: "The AppDab account identifier.")
        ], required: ["account_id"]),
        outputSchema: Schema.object(properties: [
            "account": .object(["type": .string("object")])
        ], required: ["account"]),
        outputType: "account_removal",
        supportedSurfaces: [.cli],
        safety: .write
    )

    public init() {}

    public func perform(input: RemoveAccountInput, dataProvider: any AutomationDataProviding) async throws -> AccountSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: RemoveAccountInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let account = try await account(withID: input.accountID, dataProvider: dataProvider)
        return .init(
            targetIdentifiers: [account.accountID],
            redactedSummary: "Remove API key \(account.name).",
            remotePreconditions: try ["account": .fromEncodable(account)]
        )
    }

    public func validateMutation(input: RemoveAccountInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        guard plan.remotePreconditions == (try ["account": .fromEncodable(try await account(withID: input.accountID, dataProvider: dataProvider))]) else {
            throw AutomationExecutionError.preconditionFailed("The configured account changed after preview.")
        }
    }

    public func commitMutation(input: RemoveAccountInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AccountSummary {
        let apiKey = try await dataProvider.accountStore().removeAPIKey(accountID: input.accountID)
        return .init(accountID: apiKey.id, name: apiKey.name)
    }

    public func reconcileMutation(input: RemoveAccountInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<AccountSummary> {
        .unresolved
    }

    public func summary(for output: AccountSummary) -> String {
        "Removed API key \(output.name)."
    }

    public func data(for output: AccountSummary) throws -> JSONValue {
        .object(["account": try .fromEncodable(output)])
    }

    public func redactedReplayData(for output: AccountSummary) throws -> JSONValue {
        try data(for: output)
    }

    private func account(withID accountID: String, dataProvider: any AutomationDataProviding) async throws -> AccountSummary {
        guard let apiKey = try await dataProvider.accountStore().loadAPIKeys().first(where: { $0.id == accountID }) else {
            throw AutomationActionError.invalidArguments("Could not find the account \(accountID).")
        }
        return .init(accountID: apiKey.id, name: apiKey.name)
    }
}
