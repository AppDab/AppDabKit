import AppDabServices

public struct GetXcodeCloudWorkflowAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getXcodeCloudWorkflow, title: "Get Xcode Cloud Workflow",
        description: "Read an Xcode Cloud workflow and its repository identifier.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "workflowID": Schema.string(description: "The workflowID resource identifier."),
        ], required: ["accountID", "workflowID"]),
        outputSchema: Schema.object(properties: ["workflow": Schema.xcodeCloudWorkflowOutput], required: ["workflow"]),
        outputType: "workflow", safety: .read,
    )

    public init() {}

    public func perform(input: GetXcodeCloudWorkflowInput, dataProvider: any AutomationDataProviding) async throws -> XcodeCloudWorkflow {
        try await dataProvider.getXcodeCloudWorkflow(accountID: input.accountID, workflowID: input.workflowID)
    }

    public func summary(for output: XcodeCloudWorkflow) -> String {
        "Xcode Cloud workflow: \(output.name)."
    }

    public func data(for output: XcodeCloudWorkflow) throws -> JSONValue {
        try .object(["workflow": .fromEncodable(output)])
    }
}
