import AppDabServices
import ConnectAccounts
import Foundation

public struct AddAccountAction: GuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .addAccount,
        title: "Add Account",
        description: "Validate and add an App Store Connect API key from a local private key file.",
        inputSchema: Schema.object(properties: [
            "name": Schema.string(description: "The display name for this account."),
            "key_id": Schema.string(description: "The App Store Connect API key identifier."),
            "issuer_id": Schema.string(description: "The optional issuer identifier for a Team API key."),
            "private_key_file": Schema.string(description: "The path to a local .p8 private key file.")
        ], required: ["name", "key_id", "private_key_file"]),
        outputSchema: Schema.object(properties: [
            "account": .object(["type": .string("object")]),
            "issue": .object(["type": .string("object")])
        ], required: ["account"]),
        outputType: "account_addition",
        supportedSurfaces: [.cli],
        safety: .write
    )

    public init() {}

    public func perform(input: AddAccountInput, dataProvider: any AutomationDataProviding) async throws -> AccountAddition {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: AddAccountInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let privateKey = try readPrivateKey(at: input.privateKeyFile)
        let prepared = try await prepare(input: input, privateKey: privateKey, needsRemoteValidation: true)
        return .init(
            targetIdentifiers: [prepared.apiKey.id],
            redactedSummary: "Add API key \(prepared.apiKey.name).",
            remotePreconditions: ["account_id": .string(prepared.apiKey.id)]
        )
    }

    public func validateMutation(input: AddAccountInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let accounts = try await dataProvider.accountStore().loadAPIKeys()
        guard !accounts.contains(where: { $0.id == input.keyID }) else {
            throw AutomationExecutionError.preconditionFailed("An API key with this key ID is already configured.")
        }
    }

    public func commitMutation(input: AddAccountInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AccountAddition {
        let privateKey = try readPrivateKey(at: input.privateKeyFile)
        let prepared = try await prepare(input: input, privateKey: privateKey, needsRemoteValidation: true)
        try await dataProvider.accountStore().saveAPIKey(prepared.apiKey)
        return result(from: prepared)
    }

    public func reconcileMutation(input: AddAccountInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<AccountAddition> {
        guard let account = try await dataProvider.accountStore().loadAPIKeys().first(where: { $0.id == input.keyID }) else {
            return .notApplied
        }
        return .succeeded(.init(account: .init(accountID: account.id, name: account.name)))
    }

    public func summary(for output: AccountAddition) -> String {
        output.issue == nil
            ? "Added API key \(output.account.name)."
            : "Added API key \(output.account.name) with an App Store Connect agreement warning."
    }

    public func data(for output: AccountAddition) throws -> JSONValue {
        var data: [String: JSONValue] = ["account": try .fromEncodable(output.account)]
        if let issue = output.issue {
            data["issue"] = try .fromEncodable(issue)
        }
        return .object(data)
    }

    public func redactedReplayData(for output: AccountAddition) throws -> JSONValue {
        try data(for: output)
    }

    private func readPrivateKey(at path: String) throws(AutomationActionError) -> String {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw .invalidArguments("Could not read the private key file. Check the path and permissions.")
        }
        guard let privateKey = String(data: data, encoding: .utf8),
              !privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw .invalidArguments("The private key file is empty or is not valid text.")
        }
        return privateKey
    }

    private func prepare(input: AddAccountInput, privateKey: String, needsRemoteValidation: Bool) async throws -> PreparedAutomationAPIKey {
        let apiKey: APIKey
        do {
            apiKey = if input.issuerID.isEmpty {
                try APIKey(name: input.name, keyId: input.keyID, privateKey: privateKey)
            } else {
                try APIKey(name: input.name, keyId: input.keyID, issuerId: input.issuerID, privateKey: privateKey)
            }
        } catch {
            throw AutomationActionError.invalidArguments("The entered keys are invalid. Check that they match the keys on App Store Connect.")
        }
        guard needsRemoteValidation else { return .init(apiKey: apiKey, issue: nil) }
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
        let verification = try await provider.verifyAccount(accountID: apiKey.id)
        return .init(apiKey: apiKey, issue: verification.issue)
    }

    private func result(from prepared: PreparedAutomationAPIKey) -> AccountAddition {
        .init(
            account: .init(accountID: prepared.apiKey.id, name: prepared.apiKey.name),
            issue: prepared.issue.map { .init(message: $0.message, resolutionURL: $0.resolutionURL) }
        )
    }
}

private struct PreparedAutomationAPIKey {
    let apiKey: APIKey
    let issue: AccountVerificationIssue?
}
