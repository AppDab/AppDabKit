import AppDabServices
import Foundation

public protocol BetaGroupTesterActionSpec: Sendable {
    static var id: AutomationActionID { get }
    static var title: String { get }
    static var desiredMembership: Bool { get }
    static func mutation(testerID: String) -> BetaGroupTesterMutation
}

public struct BetaGroupTesterAction<Spec: BetaGroupTesterActionSpec>: ReplayableGuardedAutomationAction {
    public static var descriptor: AutomationActionDescriptor {
        .init(
            id: Spec.id,
            title: Spec.title,
            description: "\(Spec.title) using the beta group identifier and tester identifier.",
            inputSchema: Schema.object(properties: [
                "accountID": Schema.string(description: "The AppDab account identifier."),
                "betaGroupID": Schema.string(description: "The App Store Connect beta group identifier."),
                "testerID": Schema.string(description: "The App Store Connect beta tester identifier."),
            ], required: ["accountID", "betaGroupID", "testerID"]),
            outputSchema: Schema.object(properties: [
                "membership": Schema.object(properties: [
                    "betaGroupID": Schema.string(description: "The beta group identifier."),
                    "betaGroupName": Schema.string(description: "The beta group name."),
                    "testerID": Schema.string(description: "The beta tester identifier."),
                    "isMember": Schema.outputBoolean,
                ], required: ["betaGroupID", "betaGroupName", "testerID", "isMember"]),
            ], required: ["membership"]),
            outputType: "betaGroupTesterMembership",
            safety: .write,
        )
    }

    public init() {}

    public func perform(input _: BetaGroupTesterInput, dataProvider _: any AutomationDataProviding) async throws -> BetaGroupTesterMembership {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Spec.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: BetaGroupTesterInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let membership = try await dataProvider.betaGroupTesterMembership(
            accountID: input.accountID, betaGroupID: input.betaGroupID, testerID: input.testerID,
        )
        return try .init(
            targetIdentifiers: [input.accountID, input.betaGroupID, input.testerID],
            redactedSummary: "\(Spec.title) in \(membership.betaGroupName).",
            remotePreconditions: ["membership": .fromEncodable(membership)],
        )
    }

    public func validateMutation(input: BetaGroupTesterInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let membership = try await dataProvider.betaGroupTesterMembership(
            accountID: input.accountID, betaGroupID: input.betaGroupID, testerID: input.testerID,
        )
        guard try plan.remotePreconditions["membership"] == (JSONValue.fromEncodable(membership)) else {
            throw AutomationExecutionError.preconditionFailed("Beta group tester membership changed after preview.")
        }
    }

    public func commitMutation(input: BetaGroupTesterInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaGroupTesterMembership {
        guard let membershipValue = plan.remotePreconditions["membership"] else {
            throw AutomationExecutionError.preconditionFailed("Beta group tester preview is missing its membership state.")
        }
        let membership = try JSONDecoder().decode(BetaGroupTesterMembership.self, from: JSONEncoder().encode(membershipValue))
        guard membership.isMember != Spec.desiredMembership else { return membership }
        return try await dataProvider.mutateBetaGroupTester(
            accountID: input.accountID, betaGroupID: input.betaGroupID,
            mutation: Spec.mutation(testerID: input.testerID),
        )
    }

    public func reconcileMutation(input: BetaGroupTesterInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaGroupTesterMembership> {
        let membership = try await dataProvider.betaGroupTesterMembership(
            accountID: input.accountID, betaGroupID: input.betaGroupID, testerID: input.testerID,
        )
        return membership.isMember == Spec.desiredMembership ? .succeeded(membership) : .unresolved
    }

    public func summary(for output: BetaGroupTesterMembership) -> String {
        "\(Spec.title) completed in \(output.betaGroupName)."
    }

    public func data(for output: BetaGroupTesterMembership) throws -> JSONValue {
        try .object(["membership": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: BetaGroupTesterMembership) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> BetaGroupTesterMembership {
        guard let membership = data.objectValue?["membership"] else {
            throw AutomationActionError.invalidArguments("Beta group tester replay data is missing.")
        }
        return try JSONDecoder().decode(BetaGroupTesterMembership.self, from: JSONEncoder().encode(membership))
    }
}

public enum AddTesterToBetaGroupSpec: BetaGroupTesterActionSpec {
    public static let id: AutomationActionID = .addTesterToBetaGroup
    public static let title = "Add Tester to Beta Group"
    public static let desiredMembership = true
    public static func mutation(testerID: String) -> BetaGroupTesterMutation {
        .add(testerID: testerID)
    }
}

public enum RemoveTesterFromBetaGroupSpec: BetaGroupTesterActionSpec {
    public static let id: AutomationActionID = .removeTesterFromBetaGroup
    public static let title = "Remove Tester from Beta Group"
    public static let desiredMembership = false
    public static func mutation(testerID: String) -> BetaGroupTesterMutation {
        .remove(testerID: testerID)
    }
}

public typealias AddTesterToBetaGroupAction = BetaGroupTesterAction<AddTesterToBetaGroupSpec>
public typealias RemoveTesterFromBetaGroupAction = BetaGroupTesterAction<RemoveTesterFromBetaGroupSpec>
