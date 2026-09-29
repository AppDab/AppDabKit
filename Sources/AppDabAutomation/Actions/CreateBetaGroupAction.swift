import AppDabServices
import Foundation

public struct CreateBetaGroupAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .createBetaGroup, title: "Create Beta Group", description: "Create a beta group for an app.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."), "appID": Schema.string(description: "The app identifier."),
            "name": Schema.string(description: "The beta group name."),
            "isInternalGroup": Schema.outputBoolean,
            "hasAccessToAllBuilds": Schema.outputBoolean
        ], required: ["accountID", "appID", "name", "isInternalGroup"]),
        outputSchema: Schema.object(properties: ["betaGroup": Schema.betaGroupOutput], required: ["betaGroup"]),
        outputType: "betaGroup", safety: .write
    )
    public init() {}
    public func perform(input: CreateBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> BetaGroupSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }
    public func prepareMutation(input: CreateBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let app = try await dataProvider.getApp(accountID: input.accountID, appID: input.appID)
        let matching = try await matchingGroups(input: input, dataProvider: dataProvider)
        guard matching.isEmpty else { throw AutomationActionError.invalidArguments("A beta group named \(input.name) already exists for \(app.name).") }
        return .init(targetIdentifiers: [input.accountID, input.appID, input.name], redactedSummary: "Create beta group \(input.name) for \(app.name).", remotePreconditions: ["matchingIDs": .array([])])
    }
    public func validateMutation(input: CreateBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        guard try await matchingGroups(input: input, dataProvider: dataProvider).isEmpty else { throw AutomationExecutionError.preconditionFailed("A beta group with this name appeared after preview.") }
    }
    public func commitMutation(input: CreateBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaGroupSummary {
        try await dataProvider.createBetaGroup(accountID: input.accountID, appID: input.appID, name: input.name, isInternalGroup: input.isInternalGroup, hasAccessToAllBuilds: input.hasAccessToAllBuilds)
    }
    public func reconcileMutation(input: CreateBetaGroupInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaGroupSummary> {
        let groups = try await matchingGroups(input: input, dataProvider: dataProvider)
        if groups.count == 1, groups[0].isInternalGroup == input.isInternalGroup,
           input.hasAccessToAllBuilds == nil || groups[0].hasAccessToAllBuilds == input.hasAccessToAllBuilds { return .succeeded(groups[0]) }
        return groups.isEmpty ? .notApplied : .unresolved
    }
    private func matchingGroups(input: CreateBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> [BetaGroupSummary] {
        var matches: [BetaGroupSummary] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            let page = try await dataProvider.listBetaGroups(accountID: input.accountID, appID: input.appID, pagination: .init(cursor: cursor, limit: PaginationRequest.maximumLimit))
            matches += page.betaGroups.filter { $0.name == input.name }
            cursor = page.pagination.nextCursor
            if let cursor, !seen.insert(cursor).inserted { throw ServiceError.upstream("App Store Connect returned a repeated beta group cursor.") }
        } while cursor != nil
        return matches
    }
    public func summary(for output: BetaGroupSummary) -> String { "Created beta group \(output.name)." }
    public func data(for output: BetaGroupSummary) throws -> JSONValue { .object(["betaGroup": try .fromEncodable(output)]) }
    public func redactedReplayData(for output: BetaGroupSummary) throws -> JSONValue { try data(for: output) }
    public func output(fromReplayData data: JSONValue) throws -> BetaGroupSummary { try decodeBetaGroup(data) }
}
