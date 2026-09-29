import AppDabServices
import Foundation

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
