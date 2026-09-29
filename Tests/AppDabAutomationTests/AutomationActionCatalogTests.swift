@testable import AppDabAutomation
import AppDabServices
import Foundation
import Testing

struct AutomationActionCatalogTests {
    @Test func exposesStableActionDescriptors() {
        let descriptors = AutomationActionCatalog.all

        #expect(descriptors.map(\.id) == [.listAccounts, .addAccount, .removeAccount, .verifyAccount, .listApps, .getApp, .listAppVersions, .getAppVersion, .listBuilds, .createAppVersion, .listCustomerReviews, .getCustomerReview])
        #expect(descriptors.filter { ![.addAccount, .removeAccount, .createAppVersion].contains($0.id) }.allSatisfy { $0.safety == .read })
        #expect(descriptors.filter { [.addAccount, .removeAccount, .createAppVersion].contains($0.id) }.allSatisfy { $0.safety == .write })
        #expect(AutomationActionCatalog.descriptor(named: "list_apps")?.outputType == "apps")
    }

    @Test func appListDescriptorRequiresAccountId() {
        let descriptor = AutomationActionCatalog.descriptor(for: .listApps)
        let required = descriptor?.inputSchema.objectValue?["required"]?.arrayValue

        #expect(required == [.string("accountID")])
    }

    @Test func buildListDescriptorUsesCamelCaseArguments() {
        let schema = AutomationActionCatalog.descriptor(for: .listBuilds)?.inputSchema.objectValue
        let properties = schema?["properties"]?.objectValue
        let required = schema?["required"]?.arrayValue

        #expect(properties?["accountID"] != nil)
        #expect(properties?["appID"] != nil)
        #expect(properties?["account_id"] == nil)
        #expect(required == [.string("accountID"), .string("appID")])
    }

    @Test func reviewDescriptorDocumentsLimitRange() {
        let descriptor = AutomationActionCatalog.descriptor(for: .listCustomerReviews)
        let limit = descriptor?.inputSchema.objectValue?["properties"]?.objectValue?["limit"]?.objectValue

        #expect(limit?["minimum"] == .integer(1))
        #expect(limit?["maximum"] == .integer(200))
        #expect(limit?["default"] == .integer(50))
        let cursor = descriptor?.inputSchema.objectValue?["properties"]?.objectValue?["cursor"]?.objectValue
        #expect(cursor?["type"] == .string("string"))
        #expect(descriptor?.outputSchema.objectValue?["properties"]?.objectValue?["pagination"] != nil)
    }

    @Test func schemasRejectUndocumentedArgumentsAndDescribeOutputs() {
        let descriptor = AutomationActionCatalog.descriptor(for: .listApps)

        #expect(descriptor?.inputSchema.objectValue?["additionalProperties"] == .bool(false))
        #expect(
            descriptor?.outputSchema.objectValue?["properties"]?.objectValue?["apps"]?.objectValue?["type"]
                == .string("array")
        )
        #expect(
            descriptor?.outputSchema.objectValue?["properties"]?.objectValue?["pagination"]?.objectValue?["type"]
                == .string("object")
        )
    }

    @Test func nestedOutputSchemasDescribeEncodedServiceModels() throws {
        let version = AppVersion(
            versionID: "version-1", platform: "iOS", state: "Prepare for Submission",
            version: "2.0", createdDate: .now, isFirstVersion: false
        )
        let pagination = PaginationMetadata(limit: 50, total: 1, nextCursor: "next")
        let review = CustomerReview(
            reviewID: "review-1", title: "Great", body: "Helpful", createdDate: .now,
            rating: 5, reviewerNickname: "Reviewer", territory: "USA",
            response: .init(responseID: "response-1", lastModifiedDate: .now,
                            responseBody: "Thank you", state: "Published")
        )
        let app = AppDetail(
            appID: "app-1", name: "AppDab", bundleID: "app.appdab", sku: "APPDAB",
            primaryLocale: "en-US", iconURL: URL(string: "https://example.com/icon.png"),
            contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT", displayVersions: [version]
        )
        let examples: [(AutomationActionID, JSONValue)] = [
            (.listAccounts, .object(["accounts": try .fromEncodable([AccountSummary(accountID: "account-1", name: "Primary")])])),
            (.addAccount, .object([
                "account": try .fromEncodable(AccountSummary(accountID: "account-1", name: "Primary")),
                "issue": try .fromEncodable(AccountVerificationIssue(message: "Agreement", resolutionURL: URL(string: "https://example.com")))
            ])),
            (.getApp, .object(["app": try .fromEncodable(app)])),
            (.listAppVersions, try .fromEncodable(AppVersionList(appID: "app-1", versions: [version], pagination: pagination))),
            (.listBuilds, try .fromEncodable(BuildList(appID: "app-1", builds: [
                .init(buildID: "build-1", version: "42", platform: "iOS", processingState: "VALID",
                      uploadedDate: .now, expirationDate: nil, expired: false)
            ], pagination: pagination))),
            (.listCustomerReviews, try .fromEncodable(ReviewList(appID: "app-1", reviews: [review], pagination: pagination))),
            (.getCustomerReview, .object(["review": try .fromEncodable(review)]))
        ]

        for (actionID, payload) in examples {
            let schema = try #require(AutomationActionCatalog.descriptor(for: actionID)?.outputSchema)
            assertSchema(schema, describes: payload)
        }
    }

    @Test func writeActionsRequireGuardedOrDirectRegistration() throws {
        #expect(throws: AutomationActionError.invalidArguments(
            "Write action incomplete_write must support guarded or direct execution."
        )) {
            try AutomationRegistry(actions: [AnyAutomationAction(IncompleteWriteAction.self)])
        }
        let registry = try AutomationRegistry(actions: [AnyAutomationAction(DirectWriteAction.self)])
        #expect(registry.descriptors == [DirectWriteAction.descriptor])
    }

    @Test func registryRejectsInvalidActionContractMetadata() {
        #expect(throws: AutomationActionError.invalidArguments(
            "Automation action IDs must use lowercase snake case: ListApps."
        )) {
            try AutomationRegistry(actions: [AnyAutomationAction(InvalidActionIDAction.self)])
        }
        #expect(throws: AutomationActionError.invalidArguments(
            "The input schema for invalid_schema must be an object schema."
        )) {
            try AutomationRegistry(actions: [AnyAutomationAction(InvalidSchemaAction.self)])
        }
    }
}

private func assertSchema(_ schema: JSONValue, describes value: JSONValue) {
    let definition = schema.objectValue ?? [:]
    switch value {
    case .object(let fields):
        #expect(definition["type"] == .string("object"))
        let properties = definition["properties"]?.objectValue ?? [:]
        #expect(Set(fields.keys).isSubset(of: Set(properties.keys)))
        let required = Set(definition["required"]?.arrayValue?.compactMap(\.stringValue) ?? [])
        #expect(required.isSubset(of: Set(fields.keys)))
        for (key, field) in fields {
            if let fieldSchema = properties[key] {
                assertSchema(fieldSchema, describes: field)
            }
        }
    case .array(let items):
        #expect(definition["type"] == .string("array"))
        let itemSchema = definition["items"] ?? .null
        #expect(itemSchema != .null)
        for item in items {
            assertSchema(itemSchema, describes: item)
        }
    case .string:
        #expect(definition["type"] == .string("string"))
    case .integer:
        #expect(definition["type"] == .string("integer"))
    case .double:
        #expect(definition["type"] == .string("number"))
    case .bool:
        #expect(definition["type"] == .string("boolean"))
    case .null:
        break
    }
}

private struct IncompleteWriteAction: AutomationAction {
    static let descriptor = AutomationActionDescriptor(
        id: .init(rawValue: "incomplete_write"),
        title: "Incomplete Write",
        description: "Test only.",
        inputSchema: Schema.object(properties: [:]),
        outputSchema: Schema.object(properties: [:]),
        outputType: "test",
        safety: .write
    )

    init() {}

    func perform(
        input: ListAccountsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> String {
        ""
    }

    func summary(for output: String) -> String {
        output
    }

    func data(for output: String) throws -> JSONValue {
        .object([:])
    }
}

private struct DirectWriteAction: AutomationAction {
    static let descriptor = AutomationActionDescriptor(
        id: .init(rawValue: "direct_write"),
        title: "Direct Write",
        description: "Test only.",
        inputSchema: Schema.object(properties: [:]),
        outputSchema: Schema.object(properties: [:]),
        outputType: "test",
        safety: .write
    )

    static let supportsDirectWriteExecution = true

    init() {}

    func perform(
        input: ListAccountsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> String {
        ""
    }

    func summary(for output: String) -> String {
        output
    }

    func data(for output: String) throws -> JSONValue {
        .object([:])
    }
}

private struct InvalidActionIDAction: AutomationAction {
    static let descriptor = AutomationActionDescriptor(
        id: .init(rawValue: "ListApps"), title: "Invalid", description: "Test only.",
        inputSchema: Schema.object(properties: [:]), outputSchema: Schema.object(properties: [:]),
        outputType: "test", safety: .read
    )

    init() {}
    func perform(input: ListAccountsInput, dataProvider: any AutomationDataProviding) async throws -> String { "" }
    func summary(for output: String) -> String { output }
    func data(for output: String) throws -> JSONValue { .object([:]) }
}

private struct InvalidSchemaAction: AutomationAction {
    static let descriptor = AutomationActionDescriptor(
        id: .init(rawValue: "invalid_schema"), title: "Invalid", description: "Test only.",
        inputSchema: .string("not an object"), outputSchema: Schema.object(properties: [:]),
        outputType: "test", safety: .read
    )

    init() {}
    func perform(input: ListAccountsInput, dataProvider: any AutomationDataProviding) async throws -> String { "" }
    func summary(for output: String) -> String { output }
    func data(for output: String) throws -> JSONValue { .object([:]) }
}
