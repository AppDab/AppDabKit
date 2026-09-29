import AppDabServices
import Foundation

public struct UpdateBetaGroupAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .updateBetaGroup, title: "Update Beta Group", description: "Update a beta group's editable fields.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."), "betaGroupID": Schema.string(description: "The beta group identifier."),
            "name": Schema.string(description: "A new group name."), "feedbackEnabled": Schema.outputBoolean,
            "iosBuildsAvailableForAppleSiliconMac": Schema.outputBoolean, "iosBuildsAvailableForAppleVision": Schema.outputBoolean,
            "publicLinkEnabled": Schema.outputBoolean, "publicLinkLimit": .object(["type": .string("integer"), "description": .string("A positive public link tester limit."), "minimum": .integer(1)]),
            "publicLinkLimitEnabled": Schema.outputBoolean
        ], required: ["accountID", "betaGroupID"]),
        outputSchema: Schema.object(properties: ["betaGroup": Schema.betaGroupOutput], required: ["betaGroup"]),
        outputType: "betaGroup", safety: .write
    )
    public init() {}
    public func perform(input: UpdateBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> BetaGroupSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }
    public func prepareMutation(input: UpdateBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let group = try await dataProvider.getBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
        return .init(targetIdentifiers: [input.accountID, input.betaGroupID], redactedSummary: "Update beta group \(group.name).", remotePreconditions: ["betaGroup": try .fromEncodable(group)])
    }
    public func validateMutation(input: UpdateBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let group = try await dataProvider.getBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
        guard plan.remotePreconditions["betaGroup"] == (try JSONValue.fromEncodable(group)) else { throw AutomationExecutionError.preconditionFailed("Beta group changed after preview.") }
    }
    public func commitMutation(input: UpdateBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaGroupSummary {
        if let prior = plan.remotePreconditions["betaGroup"], let group = try? JSONDecoder().decode(BetaGroupSummary.self, from: JSONEncoder().encode(prior)), input.changes.isApplied(to: group) { return group }
        return try await dataProvider.updateBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID, changes: input.changes)
    }
    public func reconcileMutation(input: UpdateBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaGroupSummary> {
        let group = try await dataProvider.getBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
        if input.changes.isApplied(to: group) { return .succeeded(group) }
        return plan.remotePreconditions["betaGroup"] == (try JSONValue.fromEncodable(group)) ? .notApplied : .unresolved
    }
    public func summary(for output: BetaGroupSummary) -> String { "Updated beta group \(output.name)." }
    public func data(for output: BetaGroupSummary) throws -> JSONValue { .object(["betaGroup": try .fromEncodable(output)]) }
    public func redactedReplayData(for output: BetaGroupSummary) throws -> JSONValue { try data(for: output) }
    public func output(fromReplayData data: JSONValue) throws -> BetaGroupSummary { try decodeBetaGroup(data) }
}
