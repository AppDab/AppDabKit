import AppDabServices
import Foundation

public struct StartXcodeCloudBuildAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .startXcodeCloudBuild,
        title: "Start Xcode Cloud Build",
        description: "Queue an Xcode Cloud build for a workflow. Omit the source reference and clean option to use Xcode Cloud defaults. Requires preview and commit.",
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

    public init() {}

    public func perform(input _: StartXcodeCloudBuildInput, dataProvider _: any AutomationDataProviding) async throws -> XcodeCloudBuildRun {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: StartXcodeCloudBuildInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let (workflow, reference) = try await target(input: input, dataProvider: dataProvider)
        let source = reference.map { " from \($0.name)" } ?? " using the default source"
        let clean = input.clean.map { $0 ? " with a clean build" : " without a clean build" } ?? ""
        return try .init(
            targetIdentifiers: [input.accountID, input.workflowID] + [input.sourceBranchOrTagID].compactMap(\.self),
            redactedSummary: "Start Xcode Cloud workflow \(workflow.name)\(source)\(clean).",
            remotePreconditions: preconditions(workflow: workflow, reference: reference),
        )
    }

    public func validateMutation(input: StartXcodeCloudBuildInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let (workflow, reference) = try await target(input: input, dataProvider: dataProvider)
        guard try plan.remotePreconditions == preconditions(workflow: workflow, reference: reference) else {
            throw AutomationExecutionError.preconditionFailed("The Xcode Cloud workflow or source reference changed after preview.")
        }
    }

    public func commitMutation(input: StartXcodeCloudBuildInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> XcodeCloudBuildRun {
        try await dataProvider.startXcodeCloudBuild(accountID: input.accountID, request: input.request)
    }

    public func reconcileMutation(input _: StartXcodeCloudBuildInput, plan _: AutomationMutationPlan, dataProvider _: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<XcodeCloudBuildRun> {
        // Apple offers no client request ID for correlating this POST with a build.
        // A matching recent run could belong to another caller; never retry an
        // ambiguous start or claim that someone else's run is ours.
        .unresolved
    }

    public func summary(for output: XcodeCloudBuildRun) -> String {
        "Queued Xcode Cloud build \(output.buildRunID)."
    }

    public func data(for output: XcodeCloudBuildRun) throws -> JSONValue {
        try .object(["buildRun": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: XcodeCloudBuildRun) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> XcodeCloudBuildRun {
        struct Replay: Decodable { let buildRun: XcodeCloudBuildRun }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Replay.self, from: JSONEncoder().encode(data)).buildRun
    }

    private func target(input: StartXcodeCloudBuildInput, dataProvider: any AutomationDataProviding) async throws -> (XcodeCloudWorkflow, XcodeCloudGitReference?) {
        let workflow = try await dataProvider.getXcodeCloudWorkflow(accountID: input.accountID, workflowID: input.workflowID)
        guard workflow.isEnabled == true, workflow.isLockedForEditing != true else {
            throw AutomationActionError.invalidArguments("The Xcode Cloud workflow must be enabled and unlocked.")
        }
        guard let referenceID = input.sourceBranchOrTagID else { return (workflow, nil) }
        let reference = try await dataProvider.getXcodeCloudGitReference(accountID: input.accountID, gitReferenceID: referenceID)
        guard reference.isDeleted != true,
              let repositoryID = workflow.repositoryID,
              reference.repositoryID == repositoryID
        else {
            throw AutomationActionError.invalidArguments("The source reference must exist in the workflow's repository.")
        }
        return (workflow, reference)
    }

    private func preconditions(workflow: XcodeCloudWorkflow, reference: XcodeCloudGitReference?) throws -> [String: JSONValue] {
        try ["workflow": .fromEncodable(workflow), "sourceReference": reference.map { try .fromEncodable($0) } ?? .null]
    }
}
