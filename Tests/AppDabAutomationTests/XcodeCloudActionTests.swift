@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

struct XcodeCloudActionTests {
    private let input = StartXcodeCloudBuildInput(accountID: "account-1", workflowID: "workflow-1", sourceBranchOrTagID: "reference-1", clean: true)

    @Test func previewDoesNotStartAndPersistedCommitReplaysWithoutStartingAgain() async throws {
        let provider = XcodeCloudDataProvider()
        let url = databaseURL()
        let executor = executor(provider, url: url)
        let plan = try await executor.preview(StartXcodeCloudBuildAction.self, input: input)
        #expect(plan.redactedSummary.contains("Release from main with a clean build"))
        #expect(await provider.startRequests.isEmpty)
        let run = try await executor.commit(StartXcodeCloudBuildAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "start-once")
        let replay = try await self.executor(provider, url: url).commit(StartXcodeCloudBuildAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "start-once")
        #expect(replay == run)
        #expect(run.createdDate == Date(timeIntervalSince1970: 200))
        #expect(await provider.startRequests == [input.request])
        #expect(await provider.accountIDs.allSatisfy { $0 == "account-1" })
    }

    @Test func changedWorkflowBlocksCommit() async throws {
        let provider = XcodeCloudDataProvider()
        let executor = executor(provider)
        let plan = try await executor.preview(StartXcodeCloudBuildAction.self, input: input)
        await provider.setWorkflow(.init(workflowID: "workflow-1", name: "Release", repositoryID: "repository-1", isEnabled: true, lastModifiedDate: Date(timeIntervalSince1970: 101)))
        await #expect(throws: AutomationExecutionError.self) {
            try await executor.commit(StartXcodeCloudBuildAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "changed")
        }
        #expect(await provider.startRequests.isEmpty)
    }

    @Test func rejectsDisabledWorkflowAndForeignOrDeletedReference() async throws {
        let provider = XcodeCloudDataProvider()
        await provider.setWorkflow(.init(workflowID: "workflow-1", name: "Disabled", isEnabled: false))
        await #expect(throws: AutomationActionError.self) { try await executor(provider).preview(StartXcodeCloudBuildAction.self, input: input) }
        await provider.setWorkflow(.init(workflowID: "workflow-1", name: "Release", repositoryID: "repository-1", isEnabled: true))
        for reference in [
            XcodeCloudGitReference(gitReferenceID: "reference-1", name: "main", repositoryID: "other"),
            XcodeCloudGitReference(gitReferenceID: "reference-1", name: "main", repositoryID: "repository-1", isDeleted: true),
        ] {
            await provider.setReference(reference)
            await #expect(throws: AutomationActionError.self) { try await executor(provider).preview(StartXcodeCloudBuildAction.self, input: input) }
        }
        #expect(await provider.startRequests.isEmpty)
    }

    @Test func ambiguousStartIsNeverRetriedOrReconciledAsAnotherCallersBuild() async throws {
        let provider = XcodeCloudDataProvider(loseResponse: true)
        let executor = executor(provider)
        let plan = try await executor.preview(StartXcodeCloudBuildAction.self, input: input)
        for expected in [AutomationExecutionError.indeterminate, .commitBlocked(.indeterminate)] {
            await #expect(throws: expected) {
                try await executor.commit(StartXcodeCloudBuildAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "lost")
            }
        }
        await #expect(throws: AutomationExecutionError.reconciliationUnresolved) {
            try await executor.execute(.init(actionID: .startXcodeCloudBuild, arguments: ["accountID": .string("account-1"), "workflowID": .string("workflow-1"), "sourceBranchOrTagID": .string("reference-1"), "clean": .bool(true)], executionContext: .init(mode: .reconcile, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "lost")))
        }
        #expect(await provider.startRequests.count == 1)
    }

    @Test func rejectsUnknownKeysInvalidTypesAndBlankIDs() throws {
        let base: [String: JSONValue] = ["accountID": .string("account-1"), "workflowID": .string("workflow-1")]
        for extra: [String: JSONValue] in [["branch": .string("main")], ["clean": .string("true")], ["clean": .null], ["sourceBranchOrTagID": .string("")], ["sourceBranchOrTagID": .null]] {
            #expect(throws: AutomationActionError.self) { try StartXcodeCloudBuildInput(arguments: base.merging(extra) { _, new in new }).validate() }
        }
        #expect(throws: AutomationActionError.self) { try StartXcodeCloudBuildInput(accountID: " ", workflowID: "workflow-1").validate() }
        let defaults = try StartXcodeCloudBuildInput(arguments: base)
        #expect(defaults.clean == nil)
        #expect(defaults.sourceBranchOrTagID == nil)
    }

    private func databaseURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("XcodeCloudTests-\(UUID().uuidString)/audit.sqlite")
    }

    private func executor(_ provider: XcodeCloudDataProvider, url: URL? = nil) -> Executor {
        Executor(dataProvider: provider, auditStore: AutomationSQLiteAuditStore(databaseURL: url ?? databaseURL()))
    }
}
