@testable import AppDabAutomation
import AppDabServices
import Foundation
import Testing

@Suite("Guarded write execution")
struct AutomationWriteExecutionTests {
    @Test func previewIsRedactedExpiringAndPersisted() async throws {
        let harness = try makeHarness(now: Date(timeIntervalSince1970: 1_000))

        let response = try await harness.preview(arguments: fixtureArguments(secret: "private review text"))
        let plan = try #require(response.plan)
        let storedPlan = try await harness.store.preview(
            confirmationFingerprint: plan.confirmationFingerprint,
            now: plan.createdAt
        )
        let encodedPlan = String(decoding: try JSONEncoder().encode(plan), as: UTF8.self)

        #expect(plan.redactedSummary == "Update fixture fixture-1.")
        #expect(plan.targetIdentifiers == ["fixture-1"])
        #expect(plan.expiresAt.timeIntervalSince(plan.createdAt) == 600)
        #expect(storedPlan == plan)
        #expect(!encodedPlan.contains("private review text"))
    }

    @Test func expiredPreviewsArePrunedWhenSavingAnotherPreview() async throws {
        let store = AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL())
        let expired = fixturePlan(
            fingerprint: "expired",
            createdAt: Date(timeIntervalSince1970: 1_000),
            expiresAt: Date(timeIntervalSince1970: 1_100)
        )
        let current = fixturePlan(
            fingerprint: "current",
            createdAt: Date(timeIntervalSince1970: 1_101),
            expiresAt: Date(timeIntervalSince1970: 1_701)
        )

        try await store.savePreview(expired)
        try await store.savePreview(current)

        #expect(try await store.preview(
            confirmationFingerprint: expired.confirmationFingerprint,
            now: current.createdAt
        ) == nil)
        #expect(try await store.preview(
            confirmationFingerprint: current.confirmationFingerprint,
            now: current.createdAt
        ) == current)
    }

    @Test(arguments: ["pending", "indeterminate", "reconciling"])
    func recoverySurvivesExpiryAndUnrelatedPreview(state: String) async throws {
        let databaseURL = temporaryDatabaseURL()
        let provider = FixtureMutationDataProvider(failure: .afterApplying)
        let harness = try makeHarness(
            provider: provider,
            store: AutomationSQLiteAuditStore(databaseURL: databaseURL)
        )
        let arguments = fixtureArguments()
        let plan = try #require(try await harness.preview(arguments: arguments).plan)
        if state == "pending" {
            _ = try await harness.store.beginCommit(
                actionID: plan.actionID,
                confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: "recover",
                now: plan.createdAt
            )
        } else {
            await #expect(throws: AutomationExecutionError.indeterminate) {
                try await harness.commit(arguments: arguments, plan: plan, key: "recover")
            }
        }

        var reconciliationClaimID: String?
        if state == "reconciling" {
            let claim = try await harness.store.beginReconciliation(
                confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: "recover",
                now: plan.expiresAt,
                pendingLeaseDuration: 600
            )
            guard case .reconcile(let claimID) = claim else {
                Issue.record("Expected reconciliation ownership.")
                return
            }
            reconciliationClaimID = claimID
        }

        // Reopen the database after confirmation expiry, as after an app restart.
        let later = try makeHarness(
            now: plan.expiresAt.addingTimeInterval(1),
            provider: provider,
            store: AutomationSQLiteAuditStore(databaseURL: databaseURL)
        )
        _ = try await later.preview(arguments: fixtureArguments(value: "unrelated"))

        // A different key still cannot use an expired confirmation. Rejecting it
        // must not discard the plan belonging to the original operation.
        await #expect(throws: AutomationExecutionError.previewExpired) {
            try await later.commit(arguments: arguments, plan: plan, key: "different")
        }
        if let reconciliationClaimID {
            await #expect(throws: AutomationExecutionError.commitBlocked(.indeterminate)) {
                try await later.reconcile(arguments: arguments, plan: plan, key: "recover")
            }
            try await harness.store.releaseReconciliation(
                idempotencyKey: "recover",
                claimID: reconciliationClaimID
            )
        }
        let result = try await later.reconcile(arguments: arguments, plan: plan, key: "recover")
        if state == "pending" {
            #expect(result.receipt == nil)
            #expect(try await later.store.auditRecord(idempotencyKey: "recover") == nil)
            #expect(await provider.mutationAttempts == 0)
            // Once resolved as not applied, the expired plan is eligible for pruning.
            _ = try await later.preview(arguments: fixtureArguments(value: "another"))
        } else {
            #expect(result.receipt != nil)
            let replay = try await later.commit(arguments: arguments, plan: plan, key: "recover")
            #expect(replay.receipt == result.receipt)
            #expect(await provider.mutationAttempts == 1)
        }
        #expect(try await later.store.preview(
            confirmationFingerprint: plan.confirmationFingerprint,
            now: plan.expiresAt.addingTimeInterval(1)
        ) == nil)
    }

    @Test func commitRequiresOriginalInputAndFreshConfirmation() async throws {
        let previewTime = Date(timeIntervalSince1970: 1_000)
        let harness = try makeHarness(now: previewTime)
        let arguments = fixtureArguments(value: "new")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)

        await #expect(throws: AutomationExecutionError.confirmationRequired) {
            try await harness.execute(
                arguments: arguments,
                context: .init(mode: .commit)
            )
        }
        await #expect(throws: AutomationExecutionError.inputChanged) {
            try await harness.commit(
                arguments: fixtureArguments(value: "changed"),
                plan: plan,
                key: "input-changed"
            )
        }

        let expiredHarness = try makeHarness(
            now: previewTime.addingTimeInterval(601),
            provider: harness.provider,
            store: harness.store
        )
        await #expect(throws: AutomationExecutionError.previewExpired) {
            try await expiredHarness.commit(arguments: arguments, plan: plan, key: "expired")
        }
    }

    @Test func changedRemoteStateFailsBeforeMutation() async throws {
        let harness = try makeHarness()
        let arguments = fixtureArguments(value: "new")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)
        await harness.provider.changeRemoteState(to: "changed elsewhere")

        await #expect(throws: AutomationExecutionError.preconditionFailed(
            "Fixture fixture-1 changed after preview."
        )) {
            try await harness.commit(arguments: arguments, plan: plan, key: "state-changed")
        }
        #expect(await harness.provider.mutationAttempts == 0)
    }

    @Test func successfulIdempotencyReplayDoesNotRepeatMutation() async throws {
        let harness = try makeHarness()
        let arguments = fixtureArguments(value: "new")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)

        let first = try await harness.commit(arguments: arguments, plan: plan, key: "stable-key")
        #expect(try await harness.store.preview(
            confirmationFingerprint: plan.confirmationFingerprint,
            now: plan.createdAt
        ) == nil)
        let replay = try await harness.commit(arguments: arguments, plan: plan, key: "stable-key")

        #expect(first.receipt == replay.receipt)
        #expect(first.data == replay.data)
        #expect(await harness.provider.mutationAttempts == 1)
        #expect(await harness.provider.currentValue == "new")
    }

    @Test func replayRequiresOriginalArgumentsEvenAfterPreviewExpires() async throws {
        let previewTime = Date(timeIntervalSince1970: 1_000)
        let harness = try makeHarness(now: previewTime)
        let arguments = fixtureArguments(value: "first")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)
        let committed = try await harness.commit(arguments: arguments, plan: plan, key: "replay-input")
        let later = try makeHarness(
            now: previewTime.addingTimeInterval(601),
            provider: harness.provider,
            store: harness.store
        )
        for mode in [AutomationExecutionMode.commit, .reconcile] {
            let context = AutomationExecutionContext(
                mode: mode, confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: "replay-input"
            )
            await #expect(throws: AutomationExecutionError.inputChanged) {
                try await later.execute(arguments: fixtureArguments(value: "changed"), context: context)
            }
            let replay = try await later.execute(arguments: arguments, context: context)
            #expect(replay.receipt == committed.receipt)
        }
        #expect(await harness.provider.mutationAttempts == 1)
    }

    @Test func reusedKeyRejectsDifferentPreview() async throws {
        let harness = try makeHarness()
        let firstArguments = fixtureArguments(value: "first")
        let firstPlan = try #require(try await harness.preview(arguments: firstArguments).plan)
        _ = try await harness.commit(arguments: firstArguments, plan: firstPlan, key: "collision")

        let secondArguments = fixtureArguments(value: "second")
        let secondPlan = try #require(try await harness.preview(arguments: secondArguments).plan)

        await #expect(throws: AutomationExecutionError.idempotencyCollision) {
            try await harness.commit(
                arguments: secondArguments,
                plan: secondPlan,
                key: "collision"
            )
        }
    }

    @Test func indeterminateOutcomeBlocksRetryUntilReconciledAsSucceeded() async throws {
        let provider = FixtureMutationDataProvider(failure: .afterApplying)
        let harness = try makeHarness(provider: provider)
        let arguments = fixtureArguments(value: "new")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)

        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await harness.commit(arguments: arguments, plan: plan, key: "uncertain")
        }
        await #expect(throws: AutomationExecutionError.commitBlocked(.indeterminate)) {
            try await harness.commit(arguments: arguments, plan: plan, key: "uncertain")
        }

        let reconciled = try await harness.reconcile(
            arguments: arguments,
            plan: plan,
            key: "uncertain"
        )
        let replay = try await harness.commit(arguments: arguments, plan: plan, key: "uncertain")

        #expect(reconciled.receipt == replay.receipt)
        #expect(reconciled.data == replay.data)
        #expect(await provider.mutationAttempts == 1)
    }

    @Test func reconciliationCanReleaseKeyWhenMutationWasNotApplied() async throws {
        let provider = FixtureMutationDataProvider(failure: .beforeApplying)
        let harness = try makeHarness(provider: provider)
        let arguments = fixtureArguments(value: "new")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)

        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await harness.commit(arguments: arguments, plan: plan, key: "retryable")
        }
        let reconciliation = try await harness.reconcile(
            arguments: arguments,
            plan: plan,
            key: "retryable"
        )
        await provider.setFailure(nil)
        let committed = try await harness.commit(
            arguments: arguments,
            plan: plan,
            key: "retryable"
        )

        #expect(reconciliation.receipt == nil)
        #expect(committed.receipt != nil)
        #expect(await provider.mutationAttempts == 2)
    }

    @Test func concurrentStoresAtomicallyClaimOneIdempotencyKey() async throws {
        let databaseURL = temporaryDatabaseURL()
        let firstStore = AutomationSQLiteAuditStore(databaseURL: databaseURL)
        let secondStore = AutomationSQLiteAuditStore(databaseURL: databaseURL)

        let outcomes = await withTaskGroup(of: String.self, returning: [String].self) { group in
            for store in [firstStore, secondStore] {
                group.addTask {
                    do {
                        let claim = try await store.beginCommit(
                            actionID: fixtureActionID,
                            confirmationFingerprint: "fingerprint",
                            idempotencyKey: "concurrent",
                            now: Date(timeIntervalSince1970: 1_000)
                        )
                        if case .execute = claim { return "execute" }
                        return "replay"
                    } catch let error as AutomationExecutionError {
                        return error.code
                    } catch {
                        return "unexpected"
                    }
                }
            }
            var values = [String]()
            for await value in group {
                values.append(value)
            }
            return values
        }

        #expect(outcomes.sorted() == ["commit_blocked", "execute"])
    }

    @Test func pendingCommitCannotReconcileUntilItsLeaseExpires() async throws {
        let store = AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL())
        let claimedAt = Date(timeIntervalSince1970: 1_000)
        _ = try await store.beginCommit(
            actionID: fixtureActionID,
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "pending",
            now: claimedAt
        )

        await #expect(throws: AutomationExecutionError.commitBlocked(.pending)) {
            try await store.beginReconciliation(
                confirmationFingerprint: "fingerprint",
                idempotencyKey: "pending",
                now: claimedAt.addingTimeInterval(599),
                pendingLeaseDuration: 600
            )
        }

        let claim = try await store.beginReconciliation(
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "pending",
            now: claimedAt.addingTimeInterval(600),
            pendingLeaseDuration: 600
        )
        guard case .reconcile = claim else {
            Issue.record("Expected the expired pending lease to permit reconciliation.")
            return
        }
        #expect(try await store.auditRecord(idempotencyKey: "pending")?.status == .indeterminate)
    }

    @Test func reconciliationLeasePreventsStaleOwnerFromDeletingSuccessfulReceipt() async throws {
        let databaseURL = temporaryDatabaseURL()
        let firstStore = AutomationSQLiteAuditStore(databaseURL: databaseURL)
        let secondStore = AutomationSQLiteAuditStore(databaseURL: databaseURL)
        let claimedAt = Date(timeIntervalSince1970: 1_000)
        let commitClaim = try await firstStore.beginCommit(
            actionID: fixtureActionID,
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "reconciliation-race",
            now: claimedAt
        )
        guard case .execute(let commitClaimID) = commitClaim else {
            Issue.record("Expected commit ownership.")
            return
        }
        try await firstStore.markIndeterminate(
            actionID: fixtureActionID,
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "reconciliation-race",
            claimID: commitClaimID
        )

        let firstClaim = try await firstStore.beginReconciliation(
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "reconciliation-race",
            now: claimedAt,
            pendingLeaseDuration: 600
        )
        guard case .reconcile(let firstClaimID) = firstClaim else {
            Issue.record("Expected the first reconciliation claim.")
            return
        }

        await #expect(throws: AutomationExecutionError.commitBlocked(.indeterminate)) {
            try await secondStore.beginReconciliation(
                confirmationFingerprint: "fingerprint",
                idempotencyKey: "reconciliation-race",
                now: claimedAt.addingTimeInterval(599),
                pendingLeaseDuration: 600
            )
        }

        let secondClaim = try await secondStore.beginReconciliation(
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "reconciliation-race",
            now: claimedAt.addingTimeInterval(600),
            pendingLeaseDuration: 600
        )
        guard case .reconcile(let secondClaimID) = secondClaim else {
            Issue.record("Expected the expired reconciliation lease to be replaced.")
            return
        }

        let receipt = AutomationMutationReceipt(
            actionID: fixtureActionID,
            confirmationFingerprint: "fingerprint",
            idempotencyKey: "reconciliation-race",
            canonicalInputHash: "input-hash",
            redactedSummary: "Reconciled fixture.",
            redactedReplayData: .object([:]),
            committedAt: claimedAt.addingTimeInterval(601)
        )
        try await secondStore.completeReconciliation(receipt, claimID: secondClaimID)

        await #expect(throws: AutomationExecutionError.commitBlocked(.indeterminate)) {
            try await firstStore.resolveNotApplied(
                confirmationFingerprint: "fingerprint",
                idempotencyKey: "reconciliation-race",
                claimID: firstClaimID
            )
        }
        let storedRecord = try #require(
            try await firstStore.auditRecord(idempotencyKey: "reconciliation-race")
        )
        #expect(storedRecord.status == .succeeded)
        #expect(storedRecord.receipt == receipt)
    }

    @Test func lateCommitCannotOverwriteReconciledReceipt() async throws {
        let store = AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL())
        let start = Date(timeIntervalSince1970: 1_000)
        let commit = try await store.beginCommit(
            actionID: fixtureActionID, confirmationFingerprint: "fingerprint",
            idempotencyKey: "late", now: start
        )
        guard case .execute(let commitID) = commit else {
            Issue.record("Expected commit ownership.")
            return
        }
        let reconciliation = try await store.beginReconciliation(
            confirmationFingerprint: "fingerprint", idempotencyKey: "late",
            now: start.addingTimeInterval(600), pendingLeaseDuration: 600
        )
        guard case .reconcile(let reconciliationID) = reconciliation else {
            Issue.record("Expected reconciliation ownership.")
            return
        }
        let receipt = AutomationMutationReceipt(
            actionID: fixtureActionID, confirmationFingerprint: "fingerprint",
            idempotencyKey: "late", canonicalInputHash: "input-hash", redactedSummary: "Reconciled",
            redactedReplayData: .object([:]), committedAt: start.addingTimeInterval(601)
        )
        try await store.completeReconciliation(receipt, claimID: reconciliationID)

        await #expect(throws: AutomationExecutionError.commitBlocked(.indeterminate)) {
            try await store.markIndeterminate(
                actionID: fixtureActionID, confirmationFingerprint: "fingerprint",
                idempotencyKey: "late", claimID: commitID
            )
        }
        await #expect(throws: AutomationExecutionError.commitBlocked(.indeterminate)) {
            try await store.completeCommit(receipt, claimID: commitID)
        }
        let record = try #require(try await store.auditRecord(idempotencyKey: "late"))
        #expect(record.status == .succeeded)
        #expect(record.receipt == receipt)
    }

    @Test func auditReceiptsRemainRedactedUntilExplicitlyCleared() async throws {
        let harness = try makeHarness()
        let arguments = fixtureArguments(secret: "sensitive request body")
        let plan = try #require(try await harness.preview(arguments: arguments).plan)
        _ = try await harness.commit(arguments: arguments, plan: plan, key: "redaction")

        let records = try await harness.store.auditRecords()
        let encodedRecords = String(decoding: try JSONEncoder().encode(records), as: UTF8.self)

        #expect(records.count == 1)
        #expect(!encodedRecords.contains("sensitive request body"))

        try await harness.store.clear()
        #expect(try await harness.store.auditRecords().isEmpty)
        #expect(try await harness.store.preview(
            confirmationFingerprint: plan.confirmationFingerprint,
            now: plan.createdAt
        ) == nil)
    }

    private func makeHarness(
        now: Date = Date(timeIntervalSince1970: 1_000),
        provider: FixtureMutationDataProvider = .init(),
        store: AutomationSQLiteAuditStore? = nil
    ) throws -> WriteHarness {
        let store = store ?? AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL())
        let registry = try AutomationRegistry(actions: [.guarded(FixtureMutationAction.self)])
        let executor = Executor(
            dataProvider: provider,
            registry: registry,
            auditStore: store,
            now: { now },
            makePlanID: { "fixture-plan" }
        )
        return WriteHarness(executor: executor, provider: provider, store: store)
    }

    private func fixtureArguments(
        value: String = "new",
        secret: String = "secret"
    ) -> [String: JSONValue] {
        [
            "target_id": .string("fixture-1"),
            "value": .string(value),
            "sensitive_text": .string(secret),
        ]
    }

    private func fixturePlan(
        fingerprint: String,
        createdAt: Date,
        expiresAt: Date
    ) -> AutomationMutationPlan {
        .init(
            planID: "plan-\(fingerprint)",
            actionID: fixtureActionID,
            targetIdentifiers: ["fixture-1"],
            redactedSummary: "Update fixture.",
            canonicalInputHash: "input-hash",
            confirmationFingerprint: fingerprint,
            remotePreconditions: [:],
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDabAutomationTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("audit.sqlite")
    }
}

private struct WriteHarness {
    let executor: Executor
    let provider: FixtureMutationDataProvider
    let store: AutomationSQLiteAuditStore

    func preview(arguments: [String: JSONValue]) async throws -> AutomationResponse {
        try await execute(arguments: arguments, context: .init(mode: .preview))
    }

    func commit(
        arguments: [String: JSONValue],
        plan: AutomationMutationPlan,
        key: String
    ) async throws -> AutomationResponse {
        try await execute(
            arguments: arguments,
            context: .init(
                mode: .commit,
                confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: key
            )
        )
    }

    func reconcile(
        arguments: [String: JSONValue],
        plan: AutomationMutationPlan,
        key: String
    ) async throws -> AutomationResponse {
        try await execute(
            arguments: arguments,
            context: .init(
                mode: .reconcile,
                confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: key
            )
        )
    }

    func execute(
        arguments: [String: JSONValue],
        context: AutomationExecutionContext
    ) async throws -> AutomationResponse {
        try await executor.execute(.init(
            actionID: fixtureActionID,
            arguments: arguments,
            surface: .cli,
            executionContext: context
        ))
    }
}

private let fixtureActionID = AutomationActionID(rawValue: "_fixture_mutation")

private struct FixtureMutationInput: AutomationActionInput {
    let targetID: String
    let value: String
    let sensitiveText: String

    init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(
            arguments,
            allowedKeys: ["target_id", "value", "sensitive_text"]
        )
        targetID = try arguments.requiredString("target_id")
        value = try arguments.requiredString("value")
        sensitiveText = try arguments.requiredString("sensitive_text")
    }
}

private struct FixtureMutationOutput: Codable, Equatable, Sendable {
    let targetID: String
    let value: String
}

private struct FixtureMutationAction: GuardedAutomationAction {
    static let descriptor = AutomationActionDescriptor(
        id: fixtureActionID,
        title: "Fixture Mutation",
        description: "Exercise guarded mutation infrastructure in tests.",
        inputSchema: Schema.object(
            properties: [
                "target_id": Schema.string(description: "Fixture target."),
                "value": Schema.string(description: "Fixture value."),
                "sensitive_text": Schema.string(description: "Sensitive fixture input."),
            ],
            required: ["target_id", "value", "sensitive_text"]
        ),
        outputSchema: Schema.object(properties: [
            "target_id": Schema.string(description: "Fixture target."),
            "value": Schema.string(description: "Committed value."),
        ], required: ["target_id", "value"]),
        outputType: "fixture",
        supportedSurfaces: [.mcp, .cli, .appIntents],
        safety: .write
    )

    init() {}

    func perform(
        input: FixtureMutationInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> FixtureMutationOutput {
        throw AutomationExecutionError.unsupportedExecutionMode(
            action: Self.descriptor.id.rawValue,
            mode: .execute
        )
    }

    func prepareMutation(
        input: FixtureMutationInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationPreparation {
        let provider = try fixtureProvider(dataProvider)
        let snapshot = await provider.fixtureSnapshot()
        return .init(
            targetIdentifiers: [input.targetID],
            redactedSummary: "Update fixture \(input.targetID).",
            remotePreconditions: ["revision": .integer(snapshot.revision)]
        )
    }

    func validateMutation(
        input: FixtureMutationInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws {
        let snapshot = try await fixtureProvider(dataProvider).fixtureSnapshot()
        guard plan.remotePreconditions["revision"] == .integer(snapshot.revision) else {
            throw AutomationExecutionError.preconditionFailed(
                "Fixture \(input.targetID) changed after preview."
            )
        }
    }

    func commitMutation(
        input: FixtureMutationInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> FixtureMutationOutput {
        try await fixtureProvider(dataProvider).apply(value: input.value)
        return .init(targetID: input.targetID, value: input.value)
    }

    func reconcileMutation(
        input: FixtureMutationInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationReconciliation<FixtureMutationOutput> {
        let snapshot = try await fixtureProvider(dataProvider).fixtureSnapshot()
        if snapshot.value == input.value {
            return .succeeded(.init(targetID: input.targetID, value: input.value))
        }
        if plan.remotePreconditions["revision"] == .integer(snapshot.revision) {
            return .notApplied
        }
        return .unresolved
    }

    func summary(for output: FixtureMutationOutput) -> String {
        "Updated fixture \(output.targetID)."
    }

    func data(for output: FixtureMutationOutput) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }

    func redactedReplayData(for output: FixtureMutationOutput) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }

    private func fixtureProvider(
        _ dataProvider: any AutomationDataProviding
    ) throws -> any FixtureMutationProviding {
        guard let provider = dataProvider as? any FixtureMutationProviding else {
            throw ServiceError.upstream("Fixture provider is unavailable.")
        }
        return provider
    }
}

private protocol FixtureMutationProviding: AutomationDataProviding {
    func fixtureSnapshot() async -> FixtureSnapshot
    func apply(value: String) async throws
}

private struct FixtureSnapshot: Sendable {
    let value: String
    let revision: Int
}

private enum FixtureFailure: Sendable {
    case beforeApplying
    case afterApplying
}

private actor FixtureMutationDataProvider: FixtureMutationProviding {
    private var value = "old"
    private var revision = 1
    private var failure: FixtureFailure?
    private(set) var mutationAttempts = 0

    init(failure: FixtureFailure? = nil) {
        self.failure = failure
    }

    var currentValue: String { value }

    func setFailure(_ failure: FixtureFailure?) {
        self.failure = failure
    }

    func changeRemoteState(to value: String) {
        self.value = value
        revision += 1
    }

    func fixtureSnapshot() -> FixtureSnapshot {
        .init(value: value, revision: revision)
    }

    func apply(value: String) throws {
        mutationAttempts += 1
        if failure == .beforeApplying {
            throw ServiceError.upstream("Fixture failed before applying.")
        }
        self.value = value
        revision += 1
        if failure == .afterApplying {
            throw ServiceError.upstream("Fixture response was lost after applying.")
        }
    }

    func listAccounts() async throws -> [AccountSummary] { [] }
    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        .init(apps: [], pagination: .init(limit: try pagination.resolvedLimit(), total: 0, nextCursor: nil))
    }

    func getApp(accountID: String, appID: String) async throws -> AppDetail {
        throw ServiceError.appNotFound(appID)
    }

    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        throw ServiceError.upstream("Customer review lookup is unavailable in this fixture.")
    }

    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        .init(
            appID: appID,
            reviews: [],
            pagination: .init(limit: try pagination.resolvedLimit(), total: 0, nextCursor: nil)
        )
    }
}
