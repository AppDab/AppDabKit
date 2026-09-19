@testable import AppDabServices
import ConnectAccounts
import Testing

struct LiveServicesTests {
    @Test func usesTheSuppliedProviderForServiceCredentialLookup() async throws {
        let apiKey = try previewAPIKey()
        let provider = TestAccountProvider(account: .init(accountID: apiKey.id, name: apiKey.name))
        let services = LiveServices(accountProvider: provider)
        let accounts = try await services.accountProvider.listAccounts()
        #expect(accounts == [.init(accountID: apiKey.id, name: apiKey.name)])
        await #expect(throws: ServiceError.accountNotFound(apiKey.id)) {
            _ = try await services.appCatalogService.listApps(accountID: apiKey.id, pagination: .init())
        }
    }
}

private struct TestAccountProvider: AccountProviding, APIKeyProviding {
    let account: AccountSummary

    func listAccounts() async throws -> [AccountSummary] {
        [account]
    }

    func apiKey(forAccountID accountID: String) throws -> APIKey {
        throw ServiceError.accountNotFound(accountID)
    }

    func verifyAccount(accountID: String) async throws -> AppDabServices.AccountVerification {
        return .init(account: .init(accountID: accountID, name: "Test account"), issue: .none)
    }
}
