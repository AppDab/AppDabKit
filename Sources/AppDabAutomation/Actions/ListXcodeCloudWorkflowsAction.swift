import AppDabServices

public struct ListXcodeCloudWorkflowsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listXcodeCloudWorkflows, title: "List Xcode Cloud Workflows",
        description: "List workflows for an app, including repository IDs. Follow pagination to read every workflow.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The appID resource identifier."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.paginationLimit,
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: ["appID": Schema.outputString, "workflows": Schema.array(items: Schema.xcodeCloudWorkflowOutput), "pagination": Schema.paginationOutput], required: ["appID", "workflows", "pagination"]),
        outputType: "workflows", safety: .read,
    )

    public init() {}

    public func perform(input: ListXcodeCloudWorkflowsInput, dataProvider: any AutomationDataProviding) async throws -> XcodeCloudWorkflowList {
        try await dataProvider.listXcodeCloudWorkflows(accountID: input.accountID, appID: input.appID, pagination: input.pagination)
    }

    public func summary(for output: XcodeCloudWorkflowList) -> String {
        "Found \(output.workflows.count) Xcode Cloud workflows."
    }

    public func data(for output: XcodeCloudWorkflowList) throws -> JSONValue {
        try .fromEncodable(output)
    }
}
