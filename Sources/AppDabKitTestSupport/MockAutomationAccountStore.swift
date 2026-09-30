import AppDabAutomation
import ConnectAccounts

struct MockAutomationAccountStore: AutomationAccountStoring {
    func loadAPIKeys() async throws -> [ConnectAccounts.APIKey] {
        []
    }

    func saveAPIKey(_: ConnectAccounts.APIKey) async throws {}

    func removeAPIKey(accountID: String) async throws -> ConnectAccounts.APIKey {
        try .init(name: accountID, keyId: "", issuerId: "", privateKey: "")
    }
}
