import AppDabServices
import ConnectAccounts
import Foundation

public struct AccountImportEffects: Sendable {
    public let loadPrivateKey: @Sendable (String) throws -> String
    public let validateCredential: @Sendable (AddAccountInput, String) throws -> APIKey
    public let verifyCredential: @Sendable (APIKey) async throws -> AccountVerificationIssue?
    public let persistCredential: @Sendable (APIKey, any AutomationAccountStoring) async throws -> Void

    public init(
        loadPrivateKey: @escaping @Sendable (String) throws -> String,
        validateCredential: @escaping @Sendable (AddAccountInput, String) throws -> APIKey,
        verifyCredential: @escaping @Sendable (APIKey) async throws -> AccountVerificationIssue?,
        persistCredential: @escaping @Sendable (APIKey, any AutomationAccountStoring) async throws -> Void
    ) {
        self.loadPrivateKey = loadPrivateKey
        self.validateCredential = validateCredential
        self.verifyCredential = verifyCredential
        self.persistCredential = persistCredential
    }

    public static let live = Self(
        loadPrivateKey: { path in
            let data: Data
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: path))
            } catch {
                throw AutomationActionError.invalidArguments("Could not read the private key file. Check the path and permissions.")
            }
            guard let privateKey = String(data: data, encoding: .utf8),
                  !privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AutomationActionError.invalidArguments("The private key file is empty or is not valid text.")
            }
            return privateKey
        },
        validateCredential: { input, privateKey in
            do {
                return if input.issuerID.isEmpty {
                    try APIKey(name: input.name, keyId: input.keyID, privateKey: privateKey)
                } else {
                    try APIKey(name: input.name, keyId: input.keyID, issuerId: input.issuerID, privateKey: privateKey)
                }
            } catch {
                throw AutomationActionError.invalidArguments("The entered keys are invalid. Check that they match the keys on App Store Connect.")
            }
        },
        verifyCredential: { apiKey in
            let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
            return try await provider.verifyAccount(accountID: apiKey.id).issue
        },
        persistCredential: { apiKey, store in
            let accounts = try await store.loadAPIKeys()
            guard !accounts.contains(where: { $0.id == apiKey.id }) else {
                throw AutomationActionError.invalidArguments("An API key with this key ID is already configured.")
            }
            try await store.saveAPIKey(apiKey)
        }
    )
}

public struct AddAccountAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .addAccount,
        title: "Add Account",
        description: "Validate and add an App Store Connect API key from a local private key file.",
        inputSchema: Schema.object(properties: [
            "name": Schema.string(description: "The display name for this account."),
            "keyID": Schema.string(description: "The App Store Connect API key identifier."),
            "issuerID": Schema.string(description: "The optional issuer identifier for a Team API key."),
            "privateKeyFile": Schema.string(description: "The path to a local .p8 private key file.")
        ], required: ["name", "keyID", "privateKeyFile"]),
        outputSchema: Schema.object(properties: [
            "account": Schema.accountSummaryOutput,
            "issue": Schema.accountIssueOutput
        ], required: ["account"]),
        outputType: "account_addition",
        safety: .write
    )

    public static let supportsDirectWriteExecution = true

    private let effects: AccountImportEffects

    public init() {
        self.init(effects: .live)
    }

    public init(effects: AccountImportEffects) {
        self.effects = effects
    }

    public func perform(input: AddAccountInput, dataProvider: any AutomationDataProviding) async throws -> AccountAddition {
        let privateKey = try effects.loadPrivateKey(input.privateKeyFile)
        let apiKey = try effects.validateCredential(input, privateKey)
        let issue = try await effects.verifyCredential(apiKey)
        try await effects.persistCredential(apiKey, dataProvider.accountStore())
        return .init(
            account: .init(accountID: apiKey.id, name: apiKey.name),
            issue: issue.map { .init(message: $0.message, resolutionURL: $0.resolutionURL) }
        )
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
}
