import AppDabServices
import Foundation

public struct SendBetaTesterInvitationAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .sendBetaTesterInvitation,
        title: "Send Beta Tester Invitation",
        description: "Send an email invitation to a registered beta tester who has not been invited yet.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The tester's app identifier."),
            "testerID": Schema.string(description: "The beta tester identifier."),
        ], required: ["accountID", "appID", "testerID"]),
        outputSchema: Schema.object(properties: ["tester": Schema.betaTesterOutput], required: ["tester"]),
        outputType: "betaTester",
        safety: .write,
    )

    public init() {}

    public func perform(input _: SendBetaTesterInvitationInput, dataProvider _: any AutomationDataProviding) async throws -> BetaTesterSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: SendBetaTesterInvitationInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let tester = try await findTester(input: input, dataProvider: dataProvider)
        guard let tester else { throw AutomationActionError.invalidArguments("The beta tester is not registered for this app.") }
        guard tester.state?.uppercased() == "NOT_INVITED" else {
            throw AutomationActionError.invalidArguments("The beta tester already has an invitation or has accepted it.")
        }
        return try .init(
            targetIdentifiers: [input.accountID, input.appID, input.testerID],
            redactedSummary: "Send an invitation to the registered beta tester.",
            remotePreconditions: ["tester": .fromEncodable(tester)],
        )
    }

    public func validateMutation(input: SendBetaTesterInvitationInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        guard let tester = try await findTester(input: input, dataProvider: dataProvider),
              try plan.remotePreconditions["tester"] == JSONValue.fromEncodable(tester),
              tester.state?.uppercased() == "NOT_INVITED"
        else {
            throw AutomationExecutionError.preconditionFailed("Beta tester state changed after preview.")
        }
    }

    public func commitMutation(input: SendBetaTesterInvitationInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaTesterSummary {
        try await dataProvider.sendBetaTesterInvitation(accountID: input.accountID, appID: input.appID, testerID: input.testerID)
    }

    public func reconcileMutation(input: SendBetaTesterInvitationInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaTesterSummary> {
        guard let tester = try await findTester(input: input, dataProvider: dataProvider) else { return .unresolved }
        return tester.state?.uppercased() == "INVITED" ? .succeeded(tester) : .unresolved
    }

    public func summary(for output: BetaTesterSummary) -> String {
        "Sent beta tester invitation to \(output.email)."
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

    private func findTester(input: SendBetaTesterInvitationInput, dataProvider: any AutomationDataProviding) async throws -> BetaTesterSummary? {
        var cursor: String?
        var seen = Set<String>()
        repeat {
            let page = try await dataProvider.listBetaTesters(
                accountID: input.accountID,
                scope: .app(input.appID),
                pagination: .init(cursor: cursor, limit: PaginationRequest.maximumLimit),
            )
            if let tester = page.testers.first(where: { $0.betaTesterID == input.testerID }) {
                return tester
            }
            cursor = page.pagination.nextCursor
            if let cursor, !seen.insert(cursor).inserted {
                throw ServiceError.upstream("App Store Connect returned a repeated beta tester cursor.")
            }
        } while cursor != nil
        return nil
    }
}
