@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

struct XcodeCloudActionTests {
    private let input = StartXcodeCloudBuildInput(accountID: "account-1", workflowID: "workflow-1", sourceBranchOrTagID: "reference-1", clean: true)

    @Test func startsDirectlyThroughTypedAndRequestExecutionWithoutConfirmation() async throws {
        let provider = XcodeCloudDataProvider()
        let executor = executor(provider)
        let run = try await executor.execute(StartXcodeCloudBuildAction.self, input: input)
        #expect(run.buildRunID == "run-1")
        let response = try await executor.execute(.init(actionID: .startXcodeCloudBuild, arguments: arguments))
        #expect(response.data.objectValue?["buildRun"]?.objectValue?["buildRunID"] == .string("run-1"))
        #expect(response.plan == nil)
        #expect(response.receipt == nil)
        #expect(await provider.startRequests == [input.request, input.request])
        #expect(await provider.accountIDs.allSatisfy { $0 == "account-1" })
        #expect(AutomationActionCatalog.descriptor(for: .startXcodeCloudBuild)?.safety == .write)
        #expect(AutomationRegistry.standard.supportsDirectWriteExecution(for: .startXcodeCloudBuild))
        #expect(try !AutomationRegistry.standard.action(for: .startXcodeCloudBuild).supportsGuardedMutation)
    }

    @Test func rejectsGuardedModesWithoutStartingABuild() async throws {
        let provider = XcodeCloudDataProvider()
        for mode: AutomationExecutionMode in [.preview, .commit, .reconcile] {
            await #expect(throws: AutomationExecutionError.unsupportedExecutionMode(action: "start_xcode_cloud_build", mode: mode)) {
                try await executor(provider).execute(.init(actionID: .startXcodeCloudBuild, arguments: arguments, executionContext: .init(mode: mode)))
            }
        }
        #expect(await provider.startRequests.isEmpty)
    }

    @Test func rejectsDisabledWorkflowAndForeignOrDeletedReference() async throws {
        let provider = XcodeCloudDataProvider()
        await provider.setWorkflow(.init(workflowID: "workflow-1", name: "Disabled", isEnabled: false))
        await #expect(throws: AutomationActionError.self) { try await executor(provider).execute(StartXcodeCloudBuildAction.self, input: input) }
        await provider.setWorkflow(.init(workflowID: "workflow-1", name: "Release", repositoryID: "repository-1", isEnabled: true))
        for reference in [
            XcodeCloudGitReference(gitReferenceID: "reference-1", name: "main", repositoryID: "other"),
            XcodeCloudGitReference(gitReferenceID: "reference-1", name: "main", repositoryID: "repository-1", isDeleted: true),
        ] {
            await provider.setReference(reference)
            await #expect(throws: AutomationActionError.self) { try await executor(provider).execute(StartXcodeCloudBuildAction.self, input: input) }
        }
        #expect(await provider.startRequests.isEmpty)
    }

    @Test func lostStartResponseIsPropagatedWithoutAutomaticallyRetrying() async throws {
        let provider = XcodeCloudDataProvider(loseResponse: true)
        await #expect(throws: AutomationActionError.upstream("The build response was lost.")) {
            try await executor(provider).execute(StartXcodeCloudBuildAction.self, input: input)
        }
        #expect(await provider.startRequests == [input.request])
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

    private var arguments: [String: JSONValue] {
        ["accountID": .string(input.accountID), "workflowID": .string(input.workflowID),
         "sourceBranchOrTagID": .string("reference-1"), "clean": .bool(true)]
    }

    private func executor(_ provider: XcodeCloudDataProvider) -> Executor {
        Executor(dataProvider: provider)
    }
}
