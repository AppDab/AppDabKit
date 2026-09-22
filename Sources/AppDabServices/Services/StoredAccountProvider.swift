import BagbutikCore
import BagbutikAppStore
import ConnectAccounts
import Foundation

public final class StoredAccountProvider: AccountProviding, APIKeyProviding, @unchecked Sendable {
    public typealias VerifyAPIKeyHandler = @Sendable (APIKey) async throws -> Void
    private let loadAPIKeys: @Sendable () async throws -> [APIKey]
    private let verifyAPIKeyHandler: VerifyAPIKeyHandler

    public init(loadAPIKeys: @escaping @Sendable () async throws -> [APIKey], verifyAPIKeyHandler: @escaping VerifyAPIKeyHandler) {
        self.loadAPIKeys = loadAPIKeys
        self.verifyAPIKeyHandler = verifyAPIKeyHandler
    }

    public convenience init(loadAPIKeys: @escaping @Sendable () async throws -> [APIKey]) {
        self.init(loadAPIKeys: loadAPIKeys, verifyAPIKeyHandler: Self.verifyAPIKeyLive)
    }

    public func listAccounts() async throws -> [AccountSummary] {
        try await loadAPIKeys()
            .sorted(using: KeyPathComparator(\.name))
            .map { AccountSummary(accountID: $0.id, name: $0.name) }
    }

    public func apiKey(forAccountID accountID: String) async throws -> APIKey {
        guard let apiKey = try await loadAPIKeys().first(where: { $0.id == accountID }) else {
            throw ServiceError.accountNotFound(accountID)
        }
        return apiKey
    }

    public func verifyAccount(accountID: String) async throws -> AccountVerification {
        let apiKey = try await apiKey(forAccountID: accountID)
        let account = AccountSummary(accountID: apiKey.id, name: apiKey.name)
        do {
            try await verifyAPIKeyHandler(apiKey)
            return .init(account: account)
        } catch {
            switch mapAPIKeyVerificationError(error) {
            case .agreementIssue(let issue):
                return .init(
                    account: account,
                    issue: .init(message: issue.message, resolutionURL: issue.resolutionURL)
                )
            case .invalidCredentials:
                throw ServiceError.authentication(invalidAPIKeyMessage)
            case .other:
                throw error
            }
        }
    }

    static func verifyAPIKeyLive(_ apiKey: APIKey) async throws {
        let service = BagbutikService(jwt: apiKey.jwt)
        _ = try await service.request(.listAppCategoriesV1(limits: [.limit(1)]))
    }
}
