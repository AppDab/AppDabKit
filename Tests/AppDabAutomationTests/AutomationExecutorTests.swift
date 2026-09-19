@testable import AppDabAutomation
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

struct MockAutomationDataProvider: AutomationDataProviding {
    let appError: ServiceError?
    let returnsEmptyCollections: Bool
    let includesReviewResponse: Bool
    let reviewRating: Int

    init(
        appError: ServiceError? = nil,
        returnsEmptyCollections: Bool = false,
        includesReviewResponse: Bool = true,
        reviewRating: Int = 5
    ) {
        self.appError = appError
        self.returnsEmptyCollections = returnsEmptyCollections
        self.includesReviewResponse = includesReviewResponse
        self.reviewRating = reviewRating
    }

    func listAccounts() async throws -> [AccountSummary] {
        guard !returnsEmptyCollections else {
            return []
        }
        return [.init(accountID: "account-1", name: "Primary")]
    }

    func verifyAccount(accountID: String) async throws -> AccountVerification {
        guard !returnsEmptyCollections else {
            throw ServiceError.accountNotFound(accountID)
        }
        return .init(account: .init(accountID: accountID, name: "Primary"))
    }

    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        if let appError {
            throw appError
        }
        let limit = try pagination.resolvedLimit()
        guard !returnsEmptyCollections else {
            return .init(apps: [], pagination: .init(limit: limit, total: 0, nextCursor: nil))
        }
        let apps = [
            AppSummary(
                appID: "app-1",
                name: "AppDab",
                bundleID: "app.appdab",
                sku: "APPDAB",
                primaryLocale: "en-US",
                iconURL: nil,
                versions: [appVersion]
            )
        ]
        return .init(
            apps: apps,
            pagination: .init(
                limit: limit,
                total: limit == 1 ? 2 : apps.count,
                nextCursor: limit == 1 ? "next-app" : nil
            )
        )
    }

    func getApp(accountID: String, appID: String) async throws -> AppDetail {
        if let appError {
            throw appError
        }
        return .init(
            appID: appID,
            name: "AppDab",
            bundleID: "app.appdab",
            sku: "APPDAB",
            primaryLocale: "en-US",
            iconURL: nil,
            contentRightsDeclaration: "doesNotUseThirdPartyContent",
            versions: [appVersion]
        )
    }

    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        throw ServiceError.upstream("Customer review lookup is unavailable in this fixture.")
    }

    func listCustomerReviews(
        accountID: String,
        appID: String,
        pagination: PaginationRequest
    ) async throws -> ReviewList {
        let limit = try pagination.resolvedLimit()
        guard !returnsEmptyCollections else {
            return .init(appID: appID, reviews: [], pagination: .init(limit: limit, total: 0, nextCursor: nil))
        }
        let response = includesReviewResponse
            ? CustomerReviewResponse(
                responseID: "response-1",
                lastModifiedDate: Date(timeIntervalSince1970: 300),
                responseBody: "Thank you!",
                state: "PUBLISHED"
            )
            : nil
        return .init(appID: appID, reviews: [
            .init(
                reviewID: "review-1",
                title: "Great",
                body: "Love it",
                createdDate: Date(timeIntervalSince1970: 100),
                rating: reviewRating,
                reviewerNickname: "Taylor",
                territory: "USA",
                response: response
            )
        ], pagination: .init(
            limit: limit,
            total: limit == 1 ? 2 : 1,
            nextCursor: limit == 1 ? "next-review" : nil
        ))
    }

    private var appVersion: AppVersion {
        .init(
            versionID: "version-1",
            platform: "IOS",
            state: "READY_FOR_SALE",
            version: "1.2.3",
            createdDate: Date(timeIntervalSince1970: 200),
            isFirstVersion: false
        )
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
