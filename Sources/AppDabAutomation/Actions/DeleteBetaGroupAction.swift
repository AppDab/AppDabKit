import AppDabServices
import Foundation

public struct DeleteBetaGroupAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .deleteBetaGroup,
        title: "Delete Beta Group",
        description: "Delete a beta group.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "betaGroupID": Schema.string(description: "The beta group identifier."),
        ], required: ["accountID", "betaGroupID"]),
        outputSchema: Schema.object(properties: ["betaGroup": Schema.betaGroupOutput], required: ["betaGroup"]),
        outputType: "betaGroup",
        safety: .write,
    )

    public init() {}

    public func perform(input _: GetBetaGroupInput, dataProvider _: any AutomationDataProviding) async throws -> BetaGroupSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: GetBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let group = try await dataProvider.getBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
        return try .init(
            targetIdentifiers: [input.accountID, input.betaGroupID],
            redactedSummary: "Delete beta group \(group.name).",
            remotePreconditions: ["betaGroup": .fromEncodable(group)],
        )
    }

    public func validateMutation(input: GetBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let group = try await dataProvider.getBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
        guard try plan.remotePreconditions["betaGroup"] == (JSONValue.fromEncodable(group)) else {
            throw AutomationExecutionError.preconditionFailed("Beta group changed after preview.")
        }
    }

    public func commitMutation(input: GetBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaGroupSummary {
        let group = try decodeGroup(from: plan)
        guard try await dataProvider.betaGroupExists(accountID: input.accountID, betaGroupID: input.betaGroupID) else {
            return group
        }
        try await dataProvider.deleteBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
        return group
    }

    public func reconcileMutation(input: GetBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaGroupSummary> {
        let groupExists = try await dataProvider.betaGroupExists(accountID: input.accountID, betaGroupID: input.betaGroupID)
        guard !groupExists else {
            return .unresolved
        }
        return try .succeeded(decodeGroup(from: plan))
    }

    public func summary(for output: BetaGroupSummary) -> String {
        "Deleted beta group \(output.name)."
    }

    public func data(for output: BetaGroupSummary) throws -> JSONValue {
        try .object(["betaGroup": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: BetaGroupSummary) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> BetaGroupSummary {
        guard let group = data.objectValue?["betaGroup"] else {
            throw AutomationActionError.invalidArguments("Beta group deletion replay data is missing.")
        }
        return try JSONDecoder().decode(BetaGroupSummary.self, from: JSONEncoder().encode(group))
    }

    private func decodeGroup(from plan: AutomationMutationPlan) throws -> BetaGroupSummary {
        guard let value = plan.remotePreconditions["betaGroup"] else {
            throw AutomationExecutionError.preconditionFailed("Beta group deletion preview is missing its group state.")
        }
        return try JSONDecoder().decode(BetaGroupSummary.self, from: JSONEncoder().encode(value))
    }
}
