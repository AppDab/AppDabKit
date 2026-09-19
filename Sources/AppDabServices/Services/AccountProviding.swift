public protocol AccountProviding: Sendable {
    func listAccounts() async throws -> [AccountSummary]
    func verifyAccount(accountID: String) async throws -> AccountVerification
}
