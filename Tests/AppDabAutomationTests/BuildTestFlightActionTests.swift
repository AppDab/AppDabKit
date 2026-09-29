@testable import AppDabAutomation
import AppDabServices
import AppDabKitTestSupport
import Foundation
import Testing

@Suite("Build TestFlight actions")
struct BuildTestFlightActionTests {
    @Test func createBetaGroupIsGuardedAndReplayedOnce() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = CreateBetaGroupInput(accountID: "account-1", appID: "app-1", name: "New Group", isInternalGroup: true)
        let plan = try await executor.preview(CreateBetaGroupAction.self, input: input)
        let group = try await executor.commit(CreateBetaGroupAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "create-group")
        let replay = try await executor.commit(CreateBetaGroupAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "create-group")
        #expect(group.name == "New Group")
        #expect(group.hasAccessToAllBuilds == true)
        #expect(replay == group)
        #expect(await provider.mutationCount == 1)
    }

    @Test func updateBetaGroupRejectsStalePreview() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = UpdateBetaGroupInput(accountID: "account-1", betaGroupID: "group-1", changes: .init(name: "New Name"))
        let plan = try await executor.preview(UpdateBetaGroupAction.self, input: input)
        await provider.setGroupName("Changed Elsewhere")
        await #expect(throws: AutomationExecutionError.preconditionFailed("Beta group changed after preview.")) {
            try await executor.commit(UpdateBetaGroupAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "stale-group-update")
        }
        #expect(await provider.mutationCount == 0)
    }

    @Test func betaGroupBuildMutationUsesGroupRelationshipAndReplaysOnce() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BetaGroupBuildInput(accountID: "account-1", betaGroupID: "group-1", buildID: "build-1")
        let plan = try await executor.preview(AddBuildToBetaGroupAction.self, input: input)
        let first = try await executor.commit(AddBuildToBetaGroupAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "group-build")
        let replay = try await executor.commit(AddBuildToBetaGroupAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "group-build")
        #expect(first.isMember)
        #expect(replay == first)
        #expect(await provider.mutationCount == 1)
    }

    @Test func betaGroupBuildPreviewRejectsChangedMembership() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BetaGroupBuildInput(accountID: "account-1", betaGroupID: "group-1", buildID: "build-1")
        let plan = try await executor.preview(AddBuildToBetaGroupAction.self, input: input)
        await provider.addGroup("group-1")
        await #expect(throws: AutomationExecutionError.preconditionFailed("Beta group build membership changed after preview.")) {
            try await executor.commit(AddBuildToBetaGroupAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "stale-group-build")
        }
        #expect(await provider.mutationCount == 0)
    }

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
        await provider.addGroup("group-1")

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

    @Test func unrelatedTesterChangesDoNotBlockGroupMutation() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BuildRelationshipInput(accountID: "account-1", buildID: "build-1", targetID: "group-1")
        let plan = try await executor.preview(AddBetaGroupToBuildAction.self, input: input)
        await provider.addTester("tester-2")

        _ = try await executor.commit(
            AddBetaGroupToBuildAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "independent-group"
        )
        #expect(await provider.mutationCount == 1)
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

    @Test func betaGroupTesterAdditionIsGuardedAndReplayed() async throws {
        let provider = BuildMutationFixture()
        let executor = makeExecutor(provider)
        let input = BetaGroupTesterInput(accountID: "account-1", betaGroupID: "group-1", testerID: "tester-2")
        let plan = try await executor.preview(AddTesterToBetaGroupAction.self, input: input)

        let added = try await executor.commit(
            AddTesterToBetaGroupAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "add-group-tester"
        )
        let replay = try await executor.commit(
            AddTesterToBetaGroupAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "add-group-tester"
        )

        #expect(added.isMember)
        #expect(replay == added)
        #expect(await provider.groupTesterIDs.contains("tester-2"))
        #expect(await provider.mutationCount == 1)
    }

    @Test func betaGroupTesterRemovalReconcilesLostResponse() async throws {
        let provider = BuildMutationFixture(failAfterMutation: true)
        let executor = makeExecutor(provider)
        let input = BetaGroupTesterInput(accountID: "account-1", betaGroupID: "group-1", testerID: "tester-1")
        let plan = try await executor.preview(RemoveTesterFromBetaGroupAction.self, input: input)

        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await executor.commit(
                RemoveTesterFromBetaGroupAction.self, input: input,
                confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "remove-group-tester"
            )
        }
        let recovered = try await executor.reconcileResult(
            RemoveTesterFromBetaGroupAction.self, input: input,
            confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "remove-group-tester"
        )

        #expect(recovered.output?.isMember == false)
        #expect(await provider.groupTesterIDs.isEmpty)
        #expect(await provider.mutationCount == 1)
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
    private var betaGroups: [BetaGroupSummary] = [.init(betaGroupID: "group-1", name: "Early Access")]
    private var groupTesters = ["tester-1"]
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
    var groupTesterIDs: [String] { groupTesters }
    var submissionID: String? { reviewSubmissionID }
    var autoNotifyEnabled: Bool? { notificationSetting }

    func addGroup(_ id: String) { groups.append(id) }
    func addTester(_ id: String) { testers.append(id) }
    func setExternalBetaState(_ state: String) { reviewState = state }
    func setGroupName(_ name: String) { betaGroups[0] = .init(betaGroupID: "group-1", name: name) }

    func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList {
        .init(appID: appID, betaGroups: betaGroups, pagination: .init(limit: try pagination.resolvedLimit(), total: betaGroups.count, nextCursor: nil))
    }

    func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary {
        guard let group = betaGroups.first(where: { $0.betaGroupID == betaGroupID }) else { throw ServiceError.upstream("Beta group not found.") }
        return group
    }

    func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary {
        mutationCount += 1
        let group = BetaGroupSummary(betaGroupID: "group-2", name: name, isInternalGroup: isInternalGroup, hasAccessToAllBuilds: hasAccessToAllBuilds)
        betaGroups.append(group)
        return group
    }

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

    func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        let testerIDs: [String]
        let groupIDs: [String]
        switch scope {
        case .build:
            testerIDs = []
            groupIDs = []
        case .individualTester(let id):
            testerIDs = testers.contains(id) ? [id] : []
            groupIDs = []
        case .betaGroup(let id):
            testerIDs = []
            groupIDs = groups.contains(id) ? [id] : []
        }
        return .init(
            build: summary(buildID),
            individualTesterIDs: testerIDs,
            betaGroupIDs: groupIDs,
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

    func betaGroupTesterMembership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership {
        .init(betaGroupID: betaGroupID, betaGroupName: "Early Access", testerID: testerID, isMember: groupTesters.contains(testerID))
    }

    func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        mutationCount += 1
        let testerID: String
        switch mutation {
        case .add(let id):
            testerID = id
            groupTesters.append(id)
        case .remove(let id):
            testerID = id
            groupTesters.removeAll { $0 == id }
        }
        if failAfterMutation { throw ServiceError.upstream("Response lost after applying mutation.") }
        return try await betaGroupTesterMembership(accountID: accountID, betaGroupID: betaGroupID, testerID: testerID)
    }

    func betaGroupBuildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership {
        .init(betaGroup: .init(betaGroupID: betaGroupID, name: "Early Access"), buildID: buildID, isMember: groups.contains(betaGroupID))
    }

    func mutateBetaGroupBuild(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership {
        mutationCount += 1
        if add { groups.append(betaGroupID) } else { groups.removeAll { $0 == betaGroupID } }
        if failAfterMutation { throw ServiceError.upstream("Response lost after applying mutation.") }
        return try await betaGroupBuildMembership(accountID: accountID, betaGroupID: betaGroupID, buildID: buildID)
    }

    private func summary(_ buildID: String) -> BuildSummary {
        .init(
            buildID: buildID, version: "42", platform: "iOS", processingState: "VALID",
            uploadedDate: Date(timeIntervalSince1970: 100), expirationDate: nil, expired: expired
        )
    }
}
