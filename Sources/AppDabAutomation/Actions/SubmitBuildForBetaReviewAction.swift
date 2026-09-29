import AppDabServices
import Foundation

public struct SubmitBuildForBetaReviewAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .submitBuildForBetaReview,
        title: "Submit Build for Beta Review",
        description: "Submit a build for external TestFlight beta review.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "buildID": Schema.string(description: "The App Store Connect build identifier."),
            "autoNotifyEnabled": Schema.outputBoolean
        ], required: ["accountID", "buildID", "autoNotifyEnabled"]),
        outputSchema: Schema.object(properties: ["build": Schema.buildSummaryOutput], required: ["build"]),
        outputType: "build",
        safety: .write
    )

    public init() {}

    public func perform(input: SubmitBuildForBetaReviewInput, dataProvider: any AutomationDataProviding) async throws -> BuildSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: SubmitBuildForBetaReviewInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID, scope: .build)
        guard snapshot.build.expired != true, snapshot.betaReviewSubmissionID == nil,
              snapshot.externalBetaState == "READY_FOR_BETA_SUBMISSION" else {
            throw AutomationActionError.invalidArguments("Build is not ready for beta review submission.")
        }
        return .init(
            targetIdentifiers: [input.accountID, input.buildID],
            redactedSummary: "Submit build \(snapshot.build.version) for beta review.",
            remotePreconditions: ["snapshot": try .fromEncodable(snapshot)]
        )
    }

    public func validateMutation(input: SubmitBuildForBetaReviewInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID, scope: .build)
        guard plan.remotePreconditions["snapshot"] == (try JSONValue.fromEncodable(snapshot)) else {
            throw AutomationExecutionError.preconditionFailed("Build review state changed after preview.")
        }
    }

    public func commitMutation(input: SubmitBuildForBetaReviewInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BuildSummary {
        try await dataProvider.mutateBuild(
            accountID: input.accountID,
            buildID: input.buildID,
            mutation: .submitForBetaReview(autoNotifyEnabled: input.autoNotifyEnabled)
        )
    }

    public func reconcileMutation(input: SubmitBuildForBetaReviewInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BuildSummary> {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID, scope: .build)
        return snapshot.betaReviewSubmissionID != nil ? .succeeded(snapshot.build) : .unresolved
    }

    public func summary(for output: BuildSummary) -> String { "Submitted build \(output.version) for beta review." }
    public func data(for output: BuildSummary) throws -> JSONValue { .object(["build": try .fromEncodable(output)]) }
    public func redactedReplayData(for output: BuildSummary) throws -> JSONValue { try data(for: output) }
    public func output(fromReplayData data: JSONValue) throws -> BuildSummary {
        struct Replay: Decodable { let build: BuildSummary }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Replay.self, from: JSONEncoder().encode(data)).build
    }
}
