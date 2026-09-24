@testable import AppDabAutomation
import AppDabServices
import Foundation
import Testing

struct AutomationActionCatalogTests {
    @Test func exposesStableActionDescriptors() {
        let descriptors = AutomationActionCatalog.all

        #expect(descriptors.map(\.id) == [.listAccounts, .addAccount, .removeAccount, .verifyAccount, .listApps, .getApp, .createAppVersion, .listCustomerReviews, .getCustomerReview])
        #expect(descriptors.filter { ![.addAccount, .removeAccount, .createAppVersion].contains($0.id) }.allSatisfy { $0.safety == .read })
        #expect(descriptors.filter { [.addAccount, .removeAccount, .createAppVersion].contains($0.id) }.allSatisfy { $0.safety == .write })
        #expect(descriptors.filter { [.addAccount, .removeAccount].contains($0.id) }.allSatisfy { $0.supportedSurfaces == [.cli] })
        #expect(descriptors.filter { ![.addAccount, .removeAccount].contains($0.id) }.allSatisfy { $0.supportedSurfaces == [.mcp, .cli, .appIntents] })
        #expect(AutomationActionCatalog.descriptor(named: "list_apps")?.outputType == "apps")
    }

    @Test func appListDescriptorRequiresAccountId() {
        let descriptor = AutomationActionCatalog.descriptor(for: .listApps)
        let required = descriptor?.inputSchema.objectValue?["required"]?.arrayValue

        #expect(required == [.string("account_id")])
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

    @Test func writeActionsRequireExplicitGuardedRegistration() {
        #expect(throws: AutomationActionError.invalidArguments(
            "Write action incomplete_write must be registered with AnyAutomationAction.guarded."
        )) {
            try AutomationRegistry(actions: [AnyAutomationAction(IncompleteWriteAction.self)])
        }
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
        supportedSurfaces: [.cli],
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
