import AppDabServices

public struct ListBetaTestersAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listBetaTesters,
        title: "List Beta Testers",
        description: "List email beta testers for an app, beta group, or build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "List testers for this app."),
            "betaGroupID": Schema.string(description: "List testers for this beta group."),
            "buildID": Schema.string(description: "List testers for this build."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.integer(description: "Maximum testers to return, from 1 through 200.", minimum: 1, maximum: PaginationRequest.maximumLimit, default: PaginationRequest.defaultLimit),
        ], required: ["accountID"]),
        outputSchema: Schema.betaTesterListOutput,
        outputType: "betaTesters",
        safety: .read,
    )

    public init() {}

    public func perform(input: ListBetaTestersInput, dataProvider: any AutomationDataProviding) async throws -> BetaTesterList {
        try await dataProvider.listBetaTesters(accountID: input.accountID, scope: input.scope, pagination: input.pagination)
    }

    public func summary(for output: BetaTesterList) -> String {
        "Found \(output.testers.count) beta testers."
    }

    public func data(for output: BetaTesterList) throws -> JSONValue {
        try .fromEncodable(output)
    }
}
