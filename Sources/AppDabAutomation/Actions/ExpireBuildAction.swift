import AppDabServices
import Foundation

public struct ExpireBuildAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .expireBuild,
        title: "Expire Build",
        description: "Expire a build for TestFlight distribution.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "buildID": Schema.string(description: "The App Store Connect build identifier."),
        ], required: ["accountID", "buildID"]),
        outputSchema: Schema.object(properties: ["build": Schema.buildSummaryOutput], required: ["build"]),
        outputType: "build",
        safety: .write,
    )

    public init() {}

    public func perform(input _: BuildTargetInput, dataProvider _: any AutomationDataProviding) async throws -> BuildSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: BuildTargetInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID, scope: .build)
        guard snapshot.build.expired != true else {
            throw AutomationActionError.invalidArguments("Build is already expired.")
        }
        return try .init(
            targetIdentifiers: [input.accountID, input.buildID],
            redactedSummary: "Expire build \(snapshot.build.version).",
            remotePreconditions: ["snapshot": .fromEncodable(snapshot)],
        )
    }

    public func validateMutation(input: BuildTargetInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID, scope: .build)
        guard try plan.remotePreconditions["snapshot"] == (JSONValue.fromEncodable(snapshot)) else {
            throw AutomationExecutionError.preconditionFailed("Build state changed after preview.")
        }
    }

    public func commitMutation(input: BuildTargetInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BuildSummary {
        try await dataProvider.mutateBuild(accountID: input.accountID, buildID: input.buildID, mutation: .expire)
    }

    public func reconcileMutation(input: BuildTargetInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BuildSummary> {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID, scope: .build)
        return snapshot.build.expired == true ? .succeeded(snapshot.build) : .unresolved
    }

    public func summary(for output: BuildSummary) -> String {
        "Expired build \(output.version)."
    }

    public func data(for output: BuildSummary) throws -> JSONValue {
        try .object(["build": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: BuildSummary) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> BuildSummary {
        struct Replay: Decodable { let build: BuildSummary }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Replay.self, from: JSONEncoder().encode(data)).build
    }
}
