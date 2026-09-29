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
