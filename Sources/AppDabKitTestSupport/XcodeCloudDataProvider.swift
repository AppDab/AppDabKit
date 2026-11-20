import AppDabAutomation
import AppDabServices
import Foundation

/// A deterministic Xcode Cloud fixture shared by adapter contract tests.
public actor XcodeCloudDataProvider: AutomationDataProviding {
    public private(set) var startRequests: [XcodeCloudBuildRequest] = []
    public private(set) var accountIDs: [String] = []
    private var workflow = XcodeCloudWorkflow(workflowID: "workflow-1", name: "Release", repositoryID: "repository-1", isEnabled: true, lastModifiedDate: Date(timeIntervalSince1970: 100))
    private var reference = XcodeCloudGitReference(gitReferenceID: "reference-1", name: "main", canonicalName: "refs/heads/main", kind: "BRANCH", repositoryID: "repository-1", isDeleted: false)
    private let loseResponse: Bool

    public init(loseResponse: Bool = false) {
        self.loseResponse = loseResponse
    }

    public func setWorkflow(_ workflow: XcodeCloudWorkflow) {
        self.workflow = workflow
    }

    public func setReference(_ reference: XcodeCloudGitReference) {
        self.reference = reference
    }

    public func getXcodeCloudWorkflow(accountID: String, workflowID _: String) async throws -> XcodeCloudWorkflow {
        accountIDs.append(accountID)
        return workflow
    }

    public func getXcodeCloudGitReference(accountID: String, gitReferenceID _: String) async throws -> XcodeCloudGitReference {
        accountIDs.append(accountID)
        return reference
    }

    public func listXcodeCloudWorkflows(accountID _: String, appID: String, pagination: PaginationRequest) async throws -> XcodeCloudWorkflowList {
        try .init(appID: appID, workflows: [workflow], pagination: .init(limit: pagination.resolvedLimit(), total: 1, nextCursor: nil))
    }

    public func listXcodeCloudGitReferences(accountID _: String, repositoryID: String, pagination: PaginationRequest) async throws -> XcodeCloudGitReferenceList {
        try .init(repositoryID: repositoryID, gitReferences: [reference], pagination: .init(limit: pagination.resolvedLimit(), total: 1, nextCursor: nil))
    }

    public func startXcodeCloudBuild(accountID: String, request: XcodeCloudBuildRequest) async throws -> XcodeCloudBuildRun {
        accountIDs.append(accountID)
        startRequests.append(request)
        if loseResponse {
            throw ServiceError.upstream("The build response was lost.")
        }
        return run
    }

    public func getXcodeCloudBuild(accountID _: String, buildRunID _: String) async throws -> XcodeCloudBuildRun {
        run
    }

    private var run: XcodeCloudBuildRun {
        .init(buildRunID: "run-1", number: 42, workflowID: "workflow-1", sourceBranchOrTagID: "reference-1", executionProgress: "PENDING", createdDate: Date(timeIntervalSince1970: 200))
    }

    public func listAccounts() async throws -> [AccountSummary] {
        [.init(accountID: "account-1", name: "Primary")]
    }

    public func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        try await MockAutomationDataProvider().listApps(accountID: accountID, pagination: pagination)
    }

    public func getApp(accountID: String, appID: String) async throws -> AppDetail {
        try await MockAutomationDataProvider().getApp(accountID: accountID, appID: appID)
    }

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        try await MockAutomationDataProvider().getCustomerReview(accountID: accountID, reviewID: reviewID)
    }

    public func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        try await MockAutomationDataProvider().listCustomerReviews(accountID: accountID, appID: appID, pagination: pagination)
    }
}
