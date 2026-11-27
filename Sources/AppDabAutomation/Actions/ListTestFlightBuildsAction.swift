import AppDabServices

public struct ListTestFlightBuildsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listTestFlightBuilds,
        title: "List TestFlight Builds",
        description: "List an app's TestFlight builds, ordered by version and build number. Follow pagination to read every build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.integer(
                description: "Maximum builds to return, from 1 through 200.",
                minimum: 1,
                maximum: PaginationRequest.maximumLimit,
                default: PaginationRequest.defaultLimit,
            ),
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: [
            "appID": Schema.outputString,
            "builds": Schema.array(items: Schema.testFlightBuildOutput),
            "pagination": Schema.paginationOutput,
        ], required: ["appID", "builds", "pagination"]),
        outputType: "testFlightBuilds",
        safety: .read,
    )

    public init() {}

    public func perform(input: ListBuildsInput, dataProvider: any AutomationDataProviding) async throws -> TestFlightBuildList {
        try await dataProvider.testFlightBuilds().listBuilds(accountID: input.accountID, appID: input.appID, pagination: input.pagination)
    }

    public func summary(for output: TestFlightBuildList) -> String {
        "Found \(output.builds.count) builds."
    }

    public func data(for output: TestFlightBuildList) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
