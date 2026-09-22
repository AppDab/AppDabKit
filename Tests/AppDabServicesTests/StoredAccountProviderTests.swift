@testable import AppDabServices
import ConnectAccounts
import Foundation
import Testing

struct StoredAccountProviderTests {
    @Test func returnsNoAccountsWhenStoreIsEmpty() async throws {
        let provider = StoredAccountProvider(loadAPIKeys: { [] })

        let accounts = try await provider.listAccounts()

        #expect(accounts.isEmpty)
    }

    @Test func listsStoredAccountsInNameOrder() async throws {
        let provider = StoredAccountProvider(loadAPIKeys: {
            [
                try! APIKey(name: "Zulu", keyId: "AAAAAAAAAA", issuerId: "00000000-0000-0000-0000-000000000000", privateKey: previewPrivateKey),
                try! APIKey(name: "Alpha", keyId: "BBBBBBBBBB", issuerId: "00000000-0000-0000-0000-000000000001", privateKey: previewPrivateKey),
            ]
        })

        let accounts = try await provider.listAccounts()

        #expect(accounts.map(\.name) == ["Alpha", "Zulu"])
    }

    @Test func resolvesStoredAccountByIdentifier() async throws {
        let apiKey = try APIKey(
            name: "Preview",
            keyId: "AAAAAAAAAA",
            issuerId: "00000000-0000-0000-0000-000000000000",
            privateKey: previewPrivateKey
        )
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })

        let resolvedKey = try await provider.apiKey(forAccountID: apiKey.id)

        #expect(resolvedKey.id == apiKey.id)
    }

    @Test func verifiesAccountsThroughTheInjectedHandler() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] }, verifyAPIKeyHandler: { receivedKey in
            #expect(receivedKey.id == apiKey.id)
        })
        let verification = try await provider.verifyAccount(accountID: apiKey.id)
        #expect(verification.account == .init(accountID: apiKey.id, name: apiKey.name))
        #expect(verification.issue == nil)
    }

    @Test func preservesVerificationFailures() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] }, verifyAPIKeyHandler: { _ in
            throw VerificationError(message: "HTTP status code 401")
        })
        await #expect(throws: VerificationError(message: "HTTP status code 401")) {
            try await provider.verifyAccount(accountID: apiKey.id)
        }
    }

    @Test func preservesCredentialLoadingFailures() async {
        let provider = StoredAccountProvider(loadAPIKeys: { throw VerificationError(message: "Keychain unavailable") })
        await #expect(throws: VerificationError(message: "Keychain unavailable")) {
            _ = try await provider.listAccounts()
        }
    }
}

private struct VerificationError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
