import ConnectAccounts

public protocol APIKeyProviding: Sendable {
    func apiKey(forAccountID accountID: String) throws -> APIKey
}
