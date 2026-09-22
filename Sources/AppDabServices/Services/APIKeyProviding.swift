import ConnectAccounts

public protocol APIKeyProviding: Sendable {
    func apiKey(forAccountID accountID: String) async throws -> APIKey
}
