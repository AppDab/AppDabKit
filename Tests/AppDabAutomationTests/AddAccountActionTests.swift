@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import ConnectAccounts
import Foundation
import Testing

@Suite("Account import effects")
struct AddAccountActionTests {
    @Test func injectedEffectsImportWithoutReadingAFileOrContactingTheService() async throws {
        let apiKey = try testAPIKey()
        let calls = ImportCalls()
        let issue = AccountVerificationIssue(
            message: "Agreement required",
            resolutionURL: URL(string: "https://example.com/agreements")
        )
        let action = AddAccountAction(effects: .init(
            loadPrivateKey: { path in
                #expect(path == "/does/not/exist.p8")
                return "injected key"
            },
            validateCredential: { input, privateKey in
                #expect(input.keyID == apiKey.id)
                #expect(privateKey == "injected key")
                return apiKey
            },
            verifyCredential: { key in
                #expect(key.id == apiKey.id)
                await calls.record("verified")
                return issue
            },
            persistCredential: { key, _ in
                #expect(key.id == apiKey.id)
                await calls.record("persisted")
            }
        ))

        let result = try await action.perform(input: input(), dataProvider: MockAutomationDataProvider())
        let recordedCalls = await calls.values

        #expect(result.account.accountID == apiKey.id)
        #expect(result.issue?.message == "Agreement required")
        #expect(recordedCalls == ["verified", "persisted"])
    }

    @Test func failedVerificationDoesNotPersistTheCredential() async throws {
        let apiKey = try testAPIKey()
        let calls = ImportCalls()
        let action = AddAccountAction(effects: .init(
            loadPrivateKey: { _ in "injected key" },
            validateCredential: { _, _ in apiKey },
            verifyCredential: { _ in throw ImportFailure.verification },
            persistCredential: { _, _ in await calls.record("persisted") }
        ))

        await #expect(throws: ImportFailure.verification) {
            try await action.perform(input: input(), dataProvider: MockAutomationDataProvider())
        }
        let recordedCalls = await calls.values
        #expect(recordedCalls.isEmpty)
    }

    @Test func livePersistenceRejectsAnExistingKeyWithoutSavingItAgain() async throws {
        let apiKey = try testAPIKey()
        let store = RecordingAccountStore(existing: [apiKey])

        await #expect(throws: AutomationActionError.invalidArguments(
            "An API key with this key ID is already configured."
        )) {
            try await AccountImportEffects.live.persistCredential(apiKey, store)
        }
        let savedKeys = await store.savedKeys
        #expect(savedKeys.isEmpty)
    }
}

private enum ImportFailure: Error {
    case verification
}

private actor ImportCalls {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}

private actor RecordingAccountStore: AutomationAccountStoring {
    let existing: [APIKey]
    private(set) var savedKeys: [APIKey] = []

    init(existing: [APIKey]) {
        self.existing = existing
    }

    func loadAPIKeys() async throws -> [APIKey] { existing }

    func saveAPIKey(_ apiKey: APIKey) async throws {
        savedKeys.append(apiKey)
    }

    func removeAPIKey(accountID: String) async throws -> APIKey {
        throw AutomationActionError.accountNotFound(accountID)
    }
}

private func input() -> AddAccountInput {
    .init(name: "Primary", keyID: "AAAAAAAAAA", privateKeyFile: "/does/not/exist.p8")
}

private func testAPIKey() throws -> APIKey {
    try .init(
        name: "Primary",
        keyId: "AAAAAAAAAA",
        privateKey: """
        -----BEGIN PRIVATE KEY-----
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQghF6o5u7ft0FanWFm
        LKQn9bjdI9x+EutHAjA0wDfDkgShRANCAATpj+9nvBg4ipcHGSY/xqrJi8VE2qNb
        vZh9AwQzLqwcZOne8kuNMeyAtJAF1S4vNhCWqbvh1hd6nZydA8I7NHNA
        -----END PRIVATE KEY-----
        """
    )
}
