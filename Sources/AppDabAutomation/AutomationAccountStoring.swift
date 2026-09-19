import ConnectAccounts

public protocol AutomationAccountStoring: Sendable {
    func loadAPIKeys() async throws -> [APIKey]
    func saveAPIKey(_ apiKey: APIKey) async throws
    func removeAPIKey(accountID: String) async throws -> APIKey
}
