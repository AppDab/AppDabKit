@testable import AppDabAutomation
import AppDabServices
import AppDabKitTestSupport
import Foundation
import Testing

@Suite("Build TestFlight actions")
struct BuildTestFlightActionTests {
    @Test func relationshipActionsApplyAndReplayOnce() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BuildRelationshipInput(accountID: "account-1", buildID: "build-1", targetID: "tester-2")
        let plan = try await executor.preview(AddIndividualTesterToBuildAction.self, input: input)

        let build = try await executor.commit(
            AddIndividualTesterToBuildAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "add-tester"
        )
        let replay = try await executor.commit(
            AddIndividualTesterToBuildAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "add-tester"
        )

        #expect(build.buildID == "build-1")
        #expect(replay == build)
        #expect(await provider.mutationCount == 1)
        #expect(await provider.testerIDs == ["tester-1", "tester-2"])
    }

    @Test func changedRelationshipStateBlocksCommit() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BuildRelationshipInput(accountID: "account-1", buildID: "build-1", targetID: "group-1")
        let plan = try await executor.preview(AddBetaGroupToBuildAction.self, input: input)
        await provider.addTester("tester-2")

        await #expect(throws: AutomationExecutionError.preconditionFailed(
            "Build relationships changed after preview."
        )) {
            try await executor.commit(
                AddBetaGroupToBuildAction.self, input: input,
                confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "stale-group"
            )
        }
        #expect(await provider.mutationCount == 0)
    }

    @Test func lostResponseReconcilesWithoutRepeatingRelationshipMutation() async throws {
        let provider = BuildMutationFixture(failAfterMutation: true)
        let executor = makeExecutor(provider)
        let input = BuildRelationshipInput(accountID: "account-1", buildID: "build-1", targetID: "tester-1")
        let plan = try await executor.preview(RemoveIndividualTesterFromBuildAction.self, input: input)

        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await executor.commit(
                RemoveIndividualTesterFromBuildAction.self, input: input,
                confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "remove-tester"
            )
        }
        let recovered = try await executor.reconcileResult(
            RemoveIndividualTesterFromBuildAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "remove-tester"
        )

        #expect(recovered.output?.buildID == "build-1")
        #expect(await provider.mutationCount == 1)
        #expect(await provider.testerIDs.isEmpty)
    }

    @Test func betaSubmissionRequiresReadyStateAndReconcilesCreatedSubmission() async throws {
        let provider = BuildMutationFixture(externalBetaState: "PROCESSING", failAfterMutation: true)
        let executor = makeExecutor(provider)
        let input = SubmitBuildForBetaReviewInput(
            accountID: "account-1", buildID: "build-1", autoNotifyEnabled: false
        )
        await #expect(throws: AutomationActionError.invalidArguments(
            "Build is not ready for beta review submission."
        )) {
            try await executor.preview(SubmitBuildForBetaReviewAction.self, input: input)
        }
        await provider.setExternalBetaState("READY_FOR_BETA_SUBMISSION")
        let plan = try await executor.preview(SubmitBuildForBetaReviewAction.self, input: input)

        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await executor.commit(
                SubmitBuildForBetaReviewAction.self, input: input,
                confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "submit-beta"
            )
        }
        let recovered = try await executor.reconcileResult(
            SubmitBuildForBetaReviewAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "submit-beta"
        )

        #expect(recovered.output?.buildID == "build-1")
        #expect(await provider.submissionID == "submission-1")
        #expect(await provider.autoNotifyEnabled == false)
        #expect(await provider.mutationCount == 1)
    }

    @Test func expirationIsGuardedAndReportsExpiredBuild() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BuildTargetInput(accountID: "account-1", buildID: "build-1")
        let plan = try await executor.preview(ExpireBuildAction.self, input: input)
        let build = try await executor.commit(
            ExpireBuildAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "expire-build"
        )

        #expect(build.expired == true)
        #expect(await provider.mutationCount == 1)
        await #expect(throws: AutomationActionError.invalidArguments("Build is already expired.")) {
            try await executor.preview(ExpireBuildAction.self, input: input)
        }
    }

    private func makeExecutor(_ provider: BuildMutationFixture) -> Executor {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuildTestFlightActionTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("audit.sqlite")
        return Executor(
            dataProvider: provider,
            auditStore: AutomationSQLiteAuditStore(databaseURL: databaseURL)
        )
    }
}

private actor BuildMutationFixture: AutomationDataProviding {
    private let base = MockAutomationDataProvider()
    private var testers = ["tester-1"]
    private var groups: [String] = []
    private var reviewSubmissionID: String?
    private var reviewState: String
    private var notificationSetting: Bool? = true
    private var expired = false
    private let failAfterMutation: Bool
    private(set) var mutationCount = 0

    init(externalBetaState: String = "READY_FOR_BETA_SUBMISSION", failAfterMutation: Bool = false) {
        reviewState = externalBetaState
        self.failAfterMutation = failAfterMutation
    }

    var testerIDs: [String] { testers }
    var submissionID: String? { reviewSubmissionID }
    var autoNotifyEnabled: Bool? { notificationSetting }

    func addTester(_ id: String) { testers.append(id) }
    func setExternalBetaState(_ state: String) { reviewState = state }

    nonisolated func accountStore() throws -> any AutomationAccountStoring { try MockAutomationDataProvider().accountStore() }
    func listAccounts() async throws -> [AccountSummary] { try await base.listAccounts() }
    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        try await base.listApps(accountID: accountID, pagination: pagination)
    }
    func getApp(accountID: String, appID: String) async throws -> AppDetail {
        try await base.getApp(accountID: accountID, appID: appID)
    }
    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        try await base.getCustomerReview(accountID: accountID, reviewID: reviewID)
    }
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        try await base.listCustomerReviews(accountID: accountID, appID: appID, pagination: pagination)
    }

    func buildSnapshot(accountID: String, buildID: String) async throws -> BuildTestFlightSnapshot {
        .init(
            build: summary(buildID),
            individualTesterIDs: testers,
            betaGroupIDs: groups,
            betaReviewSubmissionID: reviewSubmissionID,
            externalBetaState: reviewState,
            autoNotifyEnabled: notificationSetting
        )
    }

    func mutateBuild(accountID: String, buildID: String, mutation: BuildTestFlightMutation) async throws -> BuildSummary {
        mutationCount += 1
        switch mutation {
        case .addIndividualTesters(let ids): testers.append(contentsOf: ids)
        case .removeIndividualTesters(let ids): testers.removeAll { ids.contains($0) }
        case .addBetaGroups(let ids): groups.append(contentsOf: ids)
        case .removeBetaGroups(let ids): groups.removeAll { ids.contains($0) }
        case .submitForBetaReview(let enabled):
            reviewSubmissionID = "submission-1"
            reviewState = "WAITING_FOR_BETA_REVIEW"
            notificationSetting = enabled
        case .expire: expired = true
        }
        if failAfterMutation { throw ServiceError.upstream("Response lost after applying mutation.") }
        return summary(buildID)
    }

    private func summary(_ buildID: String) -> BuildSummary {
        .init(
            buildID: buildID, version: "42", platform: "iOS", processingState: "VALID",
            uploadedDate: Date(timeIntervalSince1970: 100), expirationDate: nil, expired: expired
        )
    }
}
