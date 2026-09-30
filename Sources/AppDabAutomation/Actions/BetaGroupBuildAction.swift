import AppDabServices
import Foundation

public protocol BetaGroupBuildActionSpec: Sendable {
    static var id: AutomationActionID { get }
    static var title: String { get }
    static var adding: Bool { get }
}

public struct BetaGroupBuildAction<Spec: BetaGroupBuildActionSpec>: ReplayableGuardedAutomationAction {
    public static var descriptor: AutomationActionDescriptor {
        .init(id: Spec.id, title: Spec.title, description: "\(Spec.title) using a beta group and build identifier.",
              inputSchema: Schema.object(properties: [
                  "accountID": Schema.string(description: "The AppDab account identifier."),
                  "betaGroupID": Schema.string(description: "The beta group identifier."),
                  "buildID": Schema.string(description: "The build identifier."),
              ], required: ["accountID", "betaGroupID", "buildID"]),
              outputSchema: Schema.object(properties: ["membership": Schema.betaGroupBuildMembershipOutput], required: ["membership"]),
              outputType: "betaGroupBuildMembership", safety: .write)
    }

    public init() {}
    public func perform(input _: BetaGroupBuildInput, dataProvider _: any AutomationDataProviding) async throws -> BetaGroupBuildMembership {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Spec.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: BetaGroupBuildInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let membership = try await dataProvider.betaGroupBuildMembership(accountID: input.accountID, betaGroupID: input.betaGroupID, buildID: input.buildID)
        return try .init(targetIdentifiers: [input.accountID, input.betaGroupID, input.buildID], redactedSummary: "\(Spec.title) in \(membership.betaGroup.name).", remotePreconditions: ["membership": .fromEncodable(membership)])
    }

    public func validateMutation(input: BetaGroupBuildInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let membership = try await dataProvider.betaGroupBuildMembership(accountID: input.accountID, betaGroupID: input.betaGroupID, buildID: input.buildID)
        guard try plan.remotePreconditions["membership"] == (JSONValue.fromEncodable(membership)) else { throw AutomationExecutionError.preconditionFailed("Beta group build membership changed after preview.") }
    }

    public func commitMutation(input: BetaGroupBuildInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaGroupBuildMembership {
        guard let value = plan.remotePreconditions["membership"] else { throw AutomationExecutionError.preconditionFailed("Beta group build preview is missing its membership state.") }
        let membership = try JSONDecoder().decode(BetaGroupBuildMembership.self, from: JSONEncoder().encode(value))
        guard membership.isMember != Spec.adding else { return membership }
        return try await dataProvider.mutateBetaGroupBuild(accountID: input.accountID, betaGroupID: input.betaGroupID, buildID: input.buildID, add: Spec.adding)
    }

    public func reconcileMutation(input: BetaGroupBuildInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaGroupBuildMembership> {
        let membership = try await dataProvider.betaGroupBuildMembership(accountID: input.accountID, betaGroupID: input.betaGroupID, buildID: input.buildID)
        return membership.isMember == Spec.adding ? .succeeded(membership) : .unresolved
    }

    public func summary(for output: BetaGroupBuildMembership) -> String {
        "\(Spec.title) completed in \(output.betaGroup.name)."
    }

    public func data(for output: BetaGroupBuildMembership) throws -> JSONValue {
        try .object(["membership": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: BetaGroupBuildMembership) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> BetaGroupBuildMembership {
        guard let value = data.objectValue?["membership"] else { throw AutomationActionError.invalidArguments("Beta group build replay data is missing.") }
        return try JSONDecoder().decode(BetaGroupBuildMembership.self, from: JSONEncoder().encode(value))
    }
}
