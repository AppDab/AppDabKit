import AppDabServices
import Foundation

public protocol BuildRelationshipSpec: Sendable {
    static var id: AutomationActionID { get }
    static var title: String { get }
    static var description: String { get }
    static func currentIDs(_ snapshot: BuildTestFlightSnapshot) -> [String]
    static func mutation(_ targetID: String) -> BuildTestFlightMutation
    static var adding: Bool { get }
}

public struct BuildRelationshipAction<Spec: BuildRelationshipSpec>: ReplayableGuardedAutomationAction {
    public static var descriptor: AutomationActionDescriptor {
        .init(
            id: Spec.id,
            title: Spec.title,
            description: Spec.description,
            inputSchema: Schema.object(properties: [
                "accountID": Schema.string(description: "The AppDab account identifier."),
                "buildID": Schema.string(description: "The App Store Connect build identifier."),
                "targetID": Schema.string(description: "The beta tester or beta group identifier.")
            ], required: ["accountID", "buildID", "targetID"]),
            outputSchema: Schema.object(properties: ["build": Schema.buildSummaryOutput], required: ["build"]),
            outputType: "build",
            safety: .write
        )
    }

    public init() {}

    public func perform(input: BuildRelationshipInput, dataProvider: any AutomationDataProviding) async throws -> BuildSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Spec.id.rawValue, mode: .execute)
    }

    public func prepareMutation(
        input: BuildRelationshipInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationPreparation {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID)
        return .init(
            targetIdentifiers: [input.accountID, input.buildID, input.targetID],
            redactedSummary: "\(Spec.title) for build \(snapshot.build.version).",
            remotePreconditions: ["snapshot": try .fromEncodable(snapshot)]
        )
    }

    public func validateMutation(
        input: BuildRelationshipInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID)
        guard plan.remotePreconditions["snapshot"] == (try JSONValue.fromEncodable(snapshot)) else {
            throw AutomationExecutionError.preconditionFailed("Build relationships changed after preview.")
        }
    }

    public func commitMutation(
        input: BuildRelationshipInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> BuildSummary {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID)
        let current = Set(Spec.currentIDs(snapshot))
        let pending = Spec.adding ? !current.contains(input.targetID) : current.contains(input.targetID)
        guard pending else { return snapshot.build }
        return try await dataProvider.mutateBuild(
            accountID: input.accountID, buildID: input.buildID, mutation: Spec.mutation(input.targetID)
        )
    }

    public func reconcileMutation(
        input: BuildRelationshipInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationReconciliation<BuildSummary> {
        let snapshot = try await dataProvider.buildSnapshot(accountID: input.accountID, buildID: input.buildID)
        let current = Set(Spec.currentIDs(snapshot))
        let applied = Spec.adding ? current.contains(input.targetID) : !current.contains(input.targetID)
        return applied ? .succeeded(snapshot.build) : .unresolved
    }

    public func summary(for output: BuildSummary) -> String { "\(Spec.title) completed for build \(output.version)." }
    public func data(for output: BuildSummary) throws -> JSONValue {
        .object(["build": try .fromEncodable(output)])
    }
    public func redactedReplayData(for output: BuildSummary) throws -> JSONValue { try data(for: output) }
    public func output(fromReplayData data: JSONValue) throws -> BuildSummary {
        guard let build = data.objectValue?["build"] else {
            throw AutomationActionError.invalidArguments("Build replay data is missing.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BuildSummary.self, from: JSONEncoder().encode(build))
    }
}

public enum AddIndividualTesterToBuildSpec: BuildRelationshipSpec {
    public static let id: AutomationActionID = .addIndividualTesterToBuild
    public static let title = "Add Individual Tester to Build"
    public static let description = "Add an individual beta tester to a build."
    public static let adding = true
    public static func currentIDs(_ snapshot: BuildTestFlightSnapshot) -> [String] { snapshot.individualTesterIDs }
    public static func mutation(_ targetID: String) -> BuildTestFlightMutation { .addIndividualTesters([targetID]) }
}

public enum RemoveIndividualTesterFromBuildSpec: BuildRelationshipSpec {
    public static let id: AutomationActionID = .removeIndividualTesterFromBuild
    public static let title = "Remove Individual Tester from Build"
    public static let description = "Remove an individual beta tester from a build."
    public static let adding = false
    public static func currentIDs(_ snapshot: BuildTestFlightSnapshot) -> [String] { snapshot.individualTesterIDs }
    public static func mutation(_ targetID: String) -> BuildTestFlightMutation { .removeIndividualTesters([targetID]) }
}

public enum AddBetaGroupToBuildSpec: BuildRelationshipSpec {
    public static let id: AutomationActionID = .addBetaGroupToBuild
    public static let title = "Add Beta Group to Build"
    public static let description = "Add a beta group to a build."
    public static let adding = true
    public static func currentIDs(_ snapshot: BuildTestFlightSnapshot) -> [String] { snapshot.betaGroupIDs }
    public static func mutation(_ targetID: String) -> BuildTestFlightMutation { .addBetaGroups([targetID]) }
}

public enum RemoveBetaGroupFromBuildSpec: BuildRelationshipSpec {
    public static let id: AutomationActionID = .removeBetaGroupFromBuild
    public static let title = "Remove Beta Group from Build"
    public static let description = "Remove a beta group from a build."
    public static let adding = false
    public static func currentIDs(_ snapshot: BuildTestFlightSnapshot) -> [String] { snapshot.betaGroupIDs }
    public static func mutation(_ targetID: String) -> BuildTestFlightMutation { .removeBetaGroups([targetID]) }
}

public typealias AddIndividualTesterToBuildAction = BuildRelationshipAction<AddIndividualTesterToBuildSpec>
public typealias RemoveIndividualTesterFromBuildAction = BuildRelationshipAction<RemoveIndividualTesterFromBuildSpec>
public typealias AddBetaGroupToBuildAction = BuildRelationshipAction<AddBetaGroupToBuildSpec>
public typealias RemoveBetaGroupFromBuildAction = BuildRelationshipAction<RemoveBetaGroupFromBuildSpec>
