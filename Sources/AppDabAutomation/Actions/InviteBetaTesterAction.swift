import AppDabServices
import Foundation

public struct InviteBetaTesterAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .inviteBetaTester,
        title: "Invite Beta Tester",
        description: "Invite a new email tester to a beta group or build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "email": Schema.string(description: "The tester's email address."),
            "firstName": Schema.string(description: "The tester's first name."),
            "lastName": Schema.string(description: "The tester's last name."),
            "betaGroupID": Schema.string(description: "Add the invited tester to this beta group."),
            "buildID": Schema.string(description: "Add the invited tester to this build."),
        ], required: ["accountID", "email"]),
        outputSchema: Schema.object(properties: ["tester": Schema.betaTesterOutput], required: ["tester"]),
        outputType: "betaTester",
        safety: .write,
    )

    public init() {}

    public func perform(input _: InviteBetaTesterInput, dataProvider _: any AutomationDataProviding) async throws -> BetaTesterSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: InviteBetaTesterInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let existing = try await matchingTesters(input: input, dataProvider: dataProvider)
        guard existing.isEmpty else {
            throw AutomationActionError.invalidArguments("A beta tester with this email is already registered for the selected destination.")
        }
        let targetID = input.betaGroupID ?? input.buildID!
        let destination = input.betaGroupID == nil ? "build" : "beta group"
        return .init(
            targetIdentifiers: [input.accountID, targetID, input.email.lowercased()],
            redactedSummary: "Invite a beta tester to the selected \(destination).",
            remotePreconditions: ["existingTesterIDs": .array([])],
        )
    }

    public func validateMutation(input: InviteBetaTesterInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        guard try await matchingTesters(input: input, dataProvider: dataProvider).isEmpty else {
            throw AutomationExecutionError.preconditionFailed("A tester with this email appeared after preview.")
        }
    }

    public func commitMutation(input: InviteBetaTesterInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaTesterSummary {
        try await dataProvider.inviteBetaTester(
            accountID: input.accountID,
            email: input.email,
            firstName: input.firstName,
            lastName: input.lastName,
            destination: input.destination,
        )
    }

    public func reconcileMutation(input: InviteBetaTesterInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaTesterSummary> {
        let matches = try await matchingTesters(input: input, dataProvider: dataProvider)
        if matches.count == 1, matches[0].state?.uppercased() == "INVITED" {
            return .succeeded(matches[0])
        }
        return matches.isEmpty ? .notApplied : .unresolved
    }

    public func summary(for output: BetaTesterSummary) -> String {
        "Invited beta tester \(output.email)."
    }

    public func data(for output: BetaTesterSummary) throws -> JSONValue {
        try .object(["tester": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: BetaTesterSummary) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> BetaTesterSummary {
        guard let tester = data.objectValue?["tester"] else {
            throw AutomationActionError.invalidArguments("Beta tester replay data is missing.")
        }
        return try JSONDecoder().decode(BetaTesterSummary.self, from: JSONEncoder().encode(tester))
    }

    private func matchingTesters(input: InviteBetaTesterInput, dataProvider: any AutomationDataProviding) async throws -> [BetaTesterSummary] {
        var matches: [BetaTesterSummary] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            let page = try await dataProvider.listBetaTesters(
                accountID: input.accountID,
                scope: input.scope,
                pagination: .init(cursor: cursor, limit: PaginationRequest.maximumLimit),
            )
            matches += page.testers.filter { $0.email.caseInsensitiveCompare(input.email) == .orderedSame }
            cursor = page.pagination.nextCursor
            if let cursor, !seen.insert(cursor).inserted {
                throw ServiceError.upstream("App Store Connect returned a repeated beta tester cursor.")
            }
        } while cursor != nil
        return matches
    }
}
