@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

@Suite("Create app version action")
struct CreateAppVersionActionTests {
    @Test func previewCapturesTargetPlatformStateAndCommitIsIdempotent() async throws {
        let provider = CreateVersionDataProvider()
        let harness = try makeHarness(provider: provider)
        let plan = try #require(try await harness.preview().plan)

        #expect(plan.targetIdentifiers == ["account-1", "app-1", "IOS"])
        #expect(plan.redactedSummary == "Create version 2.0 for iOS on AppDab.")
        #expect(plan.remotePreconditions["platform"] == .string("IOS"))

        let committed = try await harness.commit(plan: plan, key: "create-version")
        let replay = try await harness.commit(plan: plan, key: "create-version")

        #expect(committed.data.objectValue?["version"]?.objectValue?["version"] == .string("2.0"))
        #expect(replay.receipt == committed.receipt)
        #expect(await provider.createAttempts == 1)
    }

    @Test func changedTargetPlatformStateBlocksCommitBeforeCreating() async throws {
        let provider = CreateVersionDataProvider()
        let harness = try makeHarness(provider: provider)
        let plan = try #require(try await harness.preview().plan)
        await provider.addVersion("1.5")

        await #expect(throws: AutomationExecutionError.preconditionFailed(
            "The iOS versions for AppDab changed after preview."
        )) {
            try await harness.commit(plan: plan, key: "state-changed")
        }
        #expect(await provider.createAttempts == 0)
    }

    @Test func reconciliationReturnsCreatedVersionAfterAnIndeterminateResponse() async throws {
        let provider = CreateVersionDataProvider(failure: .afterCreating)
        let harness = try makeHarness(provider: provider)
        let plan = try #require(try await harness.preview().plan)

        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await harness.commit(plan: plan, key: "response-lost")
        }
        let reconciled = try await harness.reconcile(plan: plan, key: "response-lost")

        #expect(reconciled.data.objectValue?["version"]?.objectValue?["version"] == .string("2.0"))
        #expect(reconciled.receipt != nil)
        #expect(await provider.createAttempts == 1)
    }

    @Test func rejectsExistingVersionDuringPreview() async throws {
        let provider = CreateVersionDataProvider(versions: ["1.0", "2.0"])
        let harness = try makeHarness(provider: provider)

        await #expect(throws: AutomationActionError.invalidArguments(
            "Version 2.0 already exists for iOS on AppDab."
        )) {
            _ = try await harness.preview()
        }
        #expect(await provider.createAttempts == 0)
    }

    @Test func typedCommitReturnsNativeVersionAndReplaysPersistedReceipt() async throws {
        let provider = CreateVersionDataProvider()
        let databaseURL = temporaryDatabaseURL()
        func executor() -> Executor {
            Executor(dataProvider: provider, auditStore: AutomationSQLiteAuditStore(databaseURL: databaseURL))
        }
        let input = CreateAppVersionInput(accountID: "account-1", appID: "app-1", platform: .iOS, version: "2.0")
        let firstExecutor = executor()
        let plan = try await firstExecutor.preview(CreateAppVersionAction.self, input: input, surface: .appIntents)
        #expect(await provider.createAttempts == 0)
        let version = try await firstExecutor.commit(
            CreateAppVersionAction.self, input: input, surface: .appIntents,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "typed-create"
        )
        #expect(version == AppVersion(
            versionID: "version-1", platform: "iOS", state: "Prepare for Submission",
            version: "2.0", createdDate: Date(timeIntervalSince1970: 2), isFirstVersion: false
        ))
        // A new executor must recover native property keys and the ISO 8601 date from disk.
        let replay = try await executor().commit(
            CreateAppVersionAction.self, input: input, surface: .appIntents,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "typed-create"
        )
        #expect(replay == version)
        #expect(await provider.createAttempts == 1)
    }

    @Test func typedCommitRejectsChangedInputAndRemoteState() async throws {
        let provider = CreateVersionDataProvider()
        let executor = Executor(dataProvider: provider, auditStore: AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL()))
        let input = CreateAppVersionInput(accountID: "account-1", appID: "app-1", platform: .iOS, version: "2.0")
        let plan = try await executor.preview(CreateAppVersionAction.self, input: input, surface: .appIntents)
        let changed = CreateAppVersionInput(accountID: "account-1", appID: "app-1", platform: .iOS, version: "3.0")
        await #expect(throws: AutomationExecutionError.inputChanged) {
            try await executor.commit(
                CreateAppVersionAction.self, input: changed, surface: .appIntents,
                confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "changed-input"
            )
        }
        await provider.addVersion("1.5")
        await #expect(throws: AutomationExecutionError.preconditionFailed(
            "The iOS versions for AppDab changed after preview."
        )) {
            try await executor.commit(
                CreateAppVersionAction.self, input: input, surface: .appIntents,
                confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "changed-state"
            )
        }
        #expect(await provider.createAttempts == 0)
    }

    private func makeHarness(provider: CreateVersionDataProvider) throws -> CreateVersionHarness {
        let registry = try AutomationRegistry(actions: [.guarded(CreateAppVersionAction.self)])
        let executor = Executor(
            dataProvider: provider,
            registry: registry,
            auditStore: AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL()),
            now: { Date(timeIntervalSince1970: 1_000) },
            makePlanID: { "create-version-plan" }
        )
        return .init(executor: executor)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CreateAppVersionActionTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("audit.sqlite")
    }
}
