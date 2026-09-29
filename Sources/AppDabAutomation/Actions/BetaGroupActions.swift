import AppDabServices
import Foundation

public struct ListBetaGroupsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listBetaGroups, title: "List Beta Groups", description: "List beta groups for an app.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.integer(description: "Maximum groups to return, from 1 through 200.", minimum: 1, maximum: PaginationRequest.maximumLimit, default: PaginationRequest.defaultLimit)
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: ["appID": Schema.outputString, "betaGroups": Schema.array(items: Schema.betaGroupOutput), "pagination": Schema.paginationOutput], required: ["appID", "betaGroups", "pagination"]),
        outputType: "betaGroups", safety: .read
    )
    public init() {}
    public func perform(input: ListBetaGroupsInput, dataProvider: any AutomationDataProviding) async throws -> BetaGroupList {
        try await dataProvider.listBetaGroups(accountID: input.accountID, appID: input.appID, pagination: input.pagination)
    }
    public func summary(for output: BetaGroupList) -> String { "Found \(output.betaGroups.count) beta groups." }
    public func data(for output: BetaGroupList) throws -> JSONValue { try .fromEncodable(output) }
}

public struct GetBetaGroupAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getBetaGroup, title: "Get Beta Group", description: "Get a beta group by identifier.",
        inputSchema: Schema.object(properties: ["accountID": Schema.string(description: "The AppDab account identifier."), "betaGroupID": Schema.string(description: "The beta group identifier.")], required: ["accountID", "betaGroupID"]),
        outputSchema: Schema.object(properties: ["betaGroup": Schema.betaGroupOutput], required: ["betaGroup"]),
        outputType: "betaGroup", safety: .read
    )
    public init() {}
    public func perform(input: GetBetaGroupInput, dataProvider: any AutomationDataProviding) async throws -> BetaGroupSummary {
        try await dataProvider.getBetaGroup(accountID: input.accountID, betaGroupID: input.betaGroupID)
    }
    public func summary(for output: BetaGroupSummary) -> String { "Found beta group \(output.name)." }
    public func data(for output: BetaGroupSummary) throws -> JSONValue { .object(["betaGroup": try .fromEncodable(output)]) }
}

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

private func decodeBetaGroup(_ data: JSONValue) throws -> BetaGroupSummary {
    guard let value = data.objectValue?["betaGroup"] else { throw AutomationActionError.invalidArguments("Beta group replay data is missing.") }
    return try JSONDecoder().decode(BetaGroupSummary.self, from: JSONEncoder().encode(value))
}
