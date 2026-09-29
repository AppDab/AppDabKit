import AppDabServices

public struct ListBuildsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listBuilds,
        title: "List Builds",
        description: "List an app's builds, newest upload first. Follow pagination to read every build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.integer(
                description: "Maximum builds to return, from 1 through 200.",
                minimum: 1,
                maximum: PaginationRequest.maximumLimit,
                default: PaginationRequest.defaultLimit
            )
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: [
            "appID": Schema.outputString,
            "builds": Schema.array(items: Schema.buildSummaryOutput),
            "pagination": Schema.paginationOutput
        ], required: ["appID", "builds", "pagination"]),
        outputType: "builds",
        safety: .read
    )

    public init() {}

    public func perform(input: ListBuildsInput, dataProvider: any AutomationDataProviding) async throws -> BuildList {
        try await dataProvider.listBuilds(accountID: input.accountID, appID: input.appID, pagination: input.pagination)
    }

    public func summary(for output: BuildList) -> String {
        "Found \(output.builds.count) builds."
    }

    public func data(for output: BuildList) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
