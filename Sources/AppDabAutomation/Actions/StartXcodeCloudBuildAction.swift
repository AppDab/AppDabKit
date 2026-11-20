import AppDabServices

public struct StartXcodeCloudBuildAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .startXcodeCloudBuild,
        title: "Start Xcode Cloud Build",
        description: "Queue an Xcode Cloud build for a workflow. Omit the source reference and clean option to use Xcode Cloud defaults. Starts immediately without confirmation. Each invocation queues a new build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "workflowID": Schema.string(description: "The Xcode Cloud workflow identifier."),
            "sourceBranchOrTagID": Schema.string(description: "An SCM Git reference identifier, not a branch name. Omit to use the default source."),
            "clean": .object(["type": .string("boolean"), "description": .string("Override whether Xcode Cloud performs a clean build.")]),
        ], required: ["accountID", "workflowID"]),
        outputSchema: Schema.object(properties: ["buildRun": Schema.xcodeCloudBuildRunOutput], required: ["buildRun"]),
        outputType: "buildRun",
        safety: .write,
    )

    public static let supportsDirectWriteExecution = true

    public init() {}

    public func perform(input: StartXcodeCloudBuildInput, dataProvider: any AutomationDataProviding) async throws -> XcodeCloudBuildRun {
        try await validateTarget(input: input, dataProvider: dataProvider)
        return try await dataProvider.startXcodeCloudBuild(accountID: input.accountID, request: input.request)
    }

    public func summary(for output: XcodeCloudBuildRun) -> String {
        "Queued Xcode Cloud build \(output.buildRunID)."
    }

    public func data(for output: XcodeCloudBuildRun) throws -> JSONValue {
        try .object(["buildRun": .fromEncodable(output)])
    }

    private func validateTarget(input: StartXcodeCloudBuildInput, dataProvider: any AutomationDataProviding) async throws {
        let workflow = try await dataProvider.getXcodeCloudWorkflow(accountID: input.accountID, workflowID: input.workflowID)
        guard workflow.isEnabled == true, workflow.isLockedForEditing != true else {
            throw AutomationActionError.invalidArguments("The Xcode Cloud workflow must be enabled and unlocked.")
        }
        guard let referenceID = input.sourceBranchOrTagID else { return }
        let reference = try await dataProvider.getXcodeCloudGitReference(accountID: input.accountID, gitReferenceID: referenceID)
        guard reference.isDeleted != true,
              let repositoryID = workflow.repositoryID,
              reference.repositoryID == repositoryID
        else {
            throw AutomationActionError.invalidArguments("The source reference must exist in the workflow's repository.")
        }
    }
}
