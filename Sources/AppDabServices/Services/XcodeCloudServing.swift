public protocol XcodeCloudServing: Sendable {
    func listWorkflows(accountID: String, appID: String, pagination: PaginationRequest) async throws -> XcodeCloudWorkflowList
    func getWorkflow(accountID: String, workflowID: String) async throws -> XcodeCloudWorkflow
    func listGitReferences(accountID: String, repositoryID: String, pagination: PaginationRequest) async throws -> XcodeCloudGitReferenceList
    func getGitReference(accountID: String, gitReferenceID: String) async throws -> XcodeCloudGitReference
    func startBuild(accountID: String, request: XcodeCloudBuildRequest) async throws -> XcodeCloudBuildRun
    func getBuildRun(accountID: String, buildRunID: String) async throws -> XcodeCloudBuildRun
}
