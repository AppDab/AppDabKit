@testable import AppDabAutomation
import AppDabServices
import Foundation
import Testing

struct AutomationActionCatalogTests {
    @Test func exposesStableActionDescriptors() {
        let descriptors = AutomationActionCatalog.all

        #expect(descriptors.map(\.id) == [.listAccounts, .addAccount, .removeAccount, .verifyAccount, .listApps, .getApp, .listAppVersions, .getAppVersion, .createAppVersion, .listCustomerReviews, .getCustomerReview])
        #expect(descriptors.filter { ![.addAccount, .removeAccount, .createAppVersion].contains($0.id) }.allSatisfy { $0.safety == .read })
        #expect(descriptors.filter { [.addAccount, .removeAccount, .createAppVersion].contains($0.id) }.allSatisfy { $0.safety == .write })
        #expect(AutomationActionCatalog.descriptor(named: "list_apps")?.outputType == "apps")
    }

    @Test func appListDescriptorRequiresAccountId() {
        let descriptor = AutomationActionCatalog.descriptor(for: .listApps)
        let required = descriptor?.inputSchema.objectValue?["required"]?.arrayValue

        #expect(required == [.string("accountID")])
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

    @Test func writeActionsRequireGuardedOrDirectRegistration() throws {
        #expect(throws: AutomationActionError.invalidArguments(
            "Write action incomplete_write must support guarded or direct execution."
        )) {
            try AutomationRegistry(actions: [AnyAutomationAction(IncompleteWriteAction.self)])
        }
        let registry = try AutomationRegistry(actions: [AnyAutomationAction(DirectWriteAction.self)])
        #expect(registry.descriptors == [DirectWriteAction.descriptor])
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
