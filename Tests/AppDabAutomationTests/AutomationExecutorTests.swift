@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

struct AutomationExecutorTests {
    @Test func listAccountsReturnsStructuredAccounts() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        let result = try await executor.execute(request(actionID: .listAccounts, arguments: [:]))

        let accounts = result.structuredContent.objectValue?["accounts"]?.arrayValue
        #expect(result.text == "Found 1 accounts.")
        #expect(accounts?.first?.objectValue?["account_id"] == .string("account-1"))
    }

    @Test func verifiesAccountsWithoutExposingCredentials() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        let result = try await executor.execute(request(
            actionID: .verifyAccount,
            arguments: ["account_id": .string("account-1")]
        ))

        #expect(result.text == "API key for Primary is valid.")
        #expect(result.structuredContent.objectValue?["account"]?.objectValue?["account_id"] == .string("account-1"))
    }

    @Test func listAppsRequiresAccountId() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        await #expect(throws: AutomationActionError.invalidArguments("Missing required argument account_id.")) {
            try await executor.execute(request(actionID: .listApps, arguments: [:]))
        }
    }

    @Test func listCustomerReviewsUsesAutomationLimitValidation() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        await #expect(throws: AutomationActionError.invalidLimit(500)) {
            try await executor.execute(request(
                actionID: .listCustomerReviews,
                arguments: [
                    "account_id": .string("account-1"),
                    "app_id": .string("app-1"),
                    "limit": .integer(500)
                ]
            ))
        }
    }

    @Test func getCustomerReviewReturnsItsPublishedResponse() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        let result = try await executor.execute(request(
            actionID: .getCustomerReview,
            arguments: [
                "account_id": .string("account-1"),
                "review_id": .string("review-1")
            ]
        ))

        let review = result.structuredContent.objectValue?["review"]?.objectValue
        #expect(result.text == "Fetched customer review titled \"Great\".")
        #expect(review?["review_id"] == .string("review-1"))
        #expect(review?["response"]?.objectValue?["response_body"] == .string("Thank you!"))
    }

    @Test func listAppsUsesSharedLimitValidation() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        await #expect(throws: AutomationActionError.invalidLimit(0)) {
            try await executor.execute(request(
                actionID: .listApps,
                arguments: [
                    "account_id": .string("account-1"),
                    "limit": .integer(0)
                ]
            ))
        }
    }

    @Test func paginatedListsExposeCursorMetadataAndRequireContinuationLimit() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        let result = try await executor.execute(request(
            actionID: .listApps,
            arguments: ["account_id": .string("account-1")]
        ))
        let pagination = result.structuredContent.objectValue?["pagination"]?.objectValue
        #expect(pagination?["limit"] == .integer(50))
        #expect(pagination?["total"] == .integer(1))
        #expect(pagination?["has_more"] == .bool(false))

        await #expect(throws: AutomationActionError.invalidArguments(
            "Argument limit is required when cursor is provided."
        )) {
            try await executor.execute(request(
                actionID: .listApps,
                arguments: ["account_id": .string("account-1"), "cursor": .string("cursor-1")]
            ))
        }

        await #expect(throws: AutomationActionError.invalidArguments(
            "Argument cursor must be an opaque pagination token."
        )) {
            try await executor.execute(request(
                actionID: .listApps,
                arguments: [
                    "account_id": .string("account-1"),
                    "cursor": .string(""),
                    "limit": .integer(50)
                ]
            ))
        }
    }

    @Test func dynamicExecutionRejectsUnknownAndIncorrectlyTypedArguments() async {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        await #expect(throws: AutomationActionError.invalidArguments("Unknown argument typo.")) {
            try await executor.execute(request(
                actionID: .listApps,
                arguments: ["account_id": .string("account-1"), "typo": .bool(true)]
            ))
        }
        await #expect(throws: AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")) {
            try await executor.execute(request(
                actionID: .listApps,
                arguments: ["account_id": .integer(1)]
            ))
        }
    }

    @Test func responseProvidesStableCrossSurfaceEnvelope() async throws {
        let executor = Executor(dataProvider: MockAutomationDataProvider())

        let response = try await executor.execute(request(actionID: .listAccounts, arguments: [:]))
        let envelope = response.envelope.objectValue

        #expect(envelope?["action"] == .string("list_accounts"))
        #expect(envelope?["summary"] == .string("Found 1 accounts."))
        #expect(envelope?["data"] == response.structuredContent)
    }

    @Test func presentsStableErrorCodes() {
        let presentedError = AutomationErrorPresentation.present(AutomationActionError.accountNotFound("missing"))

        #expect(presentedError.code == "account_not_found")
        #expect(presentedError.message == "Could not find account missing.")
    }

    @Test func typedExecutionRejectsAnImplementationThatIsNotRegistered() async throws {
        let registry = try AutomationRegistry(actions: [AnyAutomationAction(ListAccountsAction.self)])
        let executor = Executor(
            dataProvider: MockAutomationDataProvider(),
            registry: registry
        )

        await #expect(throws: AutomationActionError.invalidArguments(
            "The registered action for list_accounts does not match the requested implementation."
        )) {
            try await executor.execute(
                UnregisteredListAccountsAction.self,
                input: ListAccountsInput(),
                surface: .appIntents
            )
        }
    }

    @Test func executorTranslatesServiceFailuresToAutomationErrors() async {
        let executor = Executor(
            dataProvider: MockAutomationDataProvider(appError: .appNotFound("missing"))
        )

        await #expect(throws: AutomationActionError.appNotFound("missing")) {
            try await executor.execute(request(
                actionID: .listApps,
                arguments: ["account_id": .string("account-1")]
            ))
        }
    }
}

private func request(
    actionID: AutomationActionID,
    arguments: [String: JSONValue]
) -> AutomationRequest {
    .init(actionID: actionID, arguments: arguments, surface: .mcp)
}

private struct UnregisteredListAccountsAction: AutomationAction {
    static let descriptor = ListAccountsAction.descriptor

    init() {}

    func perform(
        input: ListAccountsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> [AccountSummary] {
        []
    }

    func summary(for output: [AccountSummary]) -> String {
        "Found no accounts."
    }

    func data(for output: [AccountSummary]) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}

extension JSONValue {
    var arrayValue: [JSONValue]? {
        guard case .array(let array) = self else {
            return nil
        }
        return array
    }
}
