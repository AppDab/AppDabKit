import BagbutikCore
import BagbutikXcodeCloud
import BagbutikXcodeCloudModels
import ConnectAccounts
import Foundation

public struct XcodeCloudService: XcodeCloudServing {
    public typealias ListWorkflowsHandler = @Sendable (APIKey, String, PaginationRequest) async throws -> XcodeCloudWorkflowList
    public typealias GetWorkflowHandler = @Sendable (APIKey, String) async throws -> XcodeCloudWorkflow
    public typealias ListGitReferencesHandler = @Sendable (APIKey, String, PaginationRequest) async throws -> XcodeCloudGitReferenceList
    public typealias GetGitReferenceHandler = @Sendable (APIKey, String) async throws -> XcodeCloudGitReference
    public typealias StartBuildHandler = @Sendable (APIKey, XcodeCloudBuildRequest) async throws -> XcodeCloudBuildRun
    public typealias GetBuildRunHandler = @Sendable (APIKey, String) async throws -> XcodeCloudBuildRun

    private let accountProvider: any APIKeyProviding
    private let listWorkflowsHandler: ListWorkflowsHandler
    private let getWorkflowHandler: GetWorkflowHandler
    private let listGitReferencesHandler: ListGitReferencesHandler
    private let getGitReferenceHandler: GetGitReferenceHandler
    private let startBuildHandler: StartBuildHandler
    private let getBuildRunHandler: GetBuildRunHandler

    public init(
        accountProvider: any APIKeyProviding,
        listWorkflowsHandler: ListWorkflowsHandler? = nil,
        getWorkflowHandler: GetWorkflowHandler? = nil,
        listGitReferencesHandler: ListGitReferencesHandler? = nil,
        getGitReferenceHandler: GetGitReferenceHandler? = nil,
        startBuildHandler: StartBuildHandler? = nil,
        getBuildRunHandler: GetBuildRunHandler? = nil,
    ) {
        self.accountProvider = accountProvider
        self.listWorkflowsHandler = listWorkflowsHandler ?? Self.listWorkflowsLive
        self.getWorkflowHandler = getWorkflowHandler ?? Self.getWorkflowLive
        self.listGitReferencesHandler = listGitReferencesHandler ?? Self.listGitReferencesLive
        self.getGitReferenceHandler = getGitReferenceHandler ?? Self.getGitReferenceLive
        self.startBuildHandler = startBuildHandler ?? Self.startBuildLive
        self.getBuildRunHandler = getBuildRunHandler ?? Self.getBuildRunLive
    }

    public func listWorkflows(accountID: String, appID: String, pagination: PaginationRequest = .init()) async throws -> XcodeCloudWorkflowList {
        try pagination.validate()
        try Self.validateID(appID, name: "appID")
        return try await withKey(accountID: accountID) { try await listWorkflowsHandler($0, appID, pagination) }
    }

    public func getWorkflow(accountID: String, workflowID: String) async throws -> XcodeCloudWorkflow {
        try Self.validateID(workflowID, name: "workflowID")
        return try await withKey(accountID: accountID) { try await getWorkflowHandler($0, workflowID) }
    }

    public func listGitReferences(accountID: String, repositoryID: String, pagination: PaginationRequest = .init()) async throws -> XcodeCloudGitReferenceList {
        try pagination.validate()
        try Self.validateID(repositoryID, name: "repositoryID")
        return try await withKey(accountID: accountID) { try await listGitReferencesHandler($0, repositoryID, pagination) }
    }

    public func getGitReference(accountID: String, gitReferenceID: String) async throws -> XcodeCloudGitReference {
        try Self.validateID(gitReferenceID, name: "gitReferenceID")
        return try await withKey(accountID: accountID) { try await getGitReferenceHandler($0, gitReferenceID) }
    }

    public func startBuild(accountID: String, request: XcodeCloudBuildRequest) async throws -> XcodeCloudBuildRun {
        try Self.validateID(request.workflowID, name: "workflowID")
        if let id = request.sourceBranchOrTagID {
            try Self.validateID(id, name: "sourceBranchOrTagID")
        }
        return try await withKey(accountID: accountID) { try await startBuildHandler($0, request) }
    }

    public func getBuildRun(accountID: String, buildRunID: String) async throws -> XcodeCloudBuildRun {
        try Self.validateID(buildRunID, name: "buildRunID")
        return try await withKey(accountID: accountID) { try await getBuildRunHandler($0, buildRunID) }
    }

    private func withKey<T: Sendable>(accountID: String, operation: (APIKey) async throws -> T) async throws -> T {
        try Self.validateID(accountID, name: "accountID")
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        do { return try await operation(key) }
        catch { throw try ServiceError.classify(error) }
    }

    private static func validateID(_ value: String, name: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidArguments("Argument \(name) must be a nonempty string.")
        }
    }

    static func workflowsRequest(productID: String, pagination: PaginationRequest) throws -> Request<CiWorkflowsResponse, ErrorResponse> {
        let request: Request<CiWorkflowsResponse, ErrorResponse> = try .listWorkflowsForCiProductV1(id: productID, includes: [.repository], limit: pagination.resolvedLimit())
        return try request.withPaginationCursor(pagination.validatedCursor())
    }

    static func gitReferencesRequest(repositoryID: String, pagination: PaginationRequest) throws -> Request<ScmGitReferencesResponse, ErrorResponse> {
        let request: Request<ScmGitReferencesResponse, ErrorResponse> = try .listGitReferencesForScmRepositoryV1(id: repositoryID, includes: [.repository], limit: pagination.resolvedLimit())
        return try request.withPaginationCursor(pagination.validatedCursor())
    }

    static func startBuildRequest(_ request: XcodeCloudBuildRequest) -> Request<CiBuildRunResponse, ErrorResponse> {
        .startCiBuildRunV1(requestBody: .init(data: .init(
            attributes: request.clean.map { .init(clean: $0) },
            relationships: .init(
                sourceBranchOrTag: request.sourceBranchOrTagID.map { .init(data: .init(id: $0)) },
                workflow: .init(data: .init(id: request.workflowID)),
            ),
        )))
    }

    private static func listWorkflowsLive(key: APIKey, appID: String, pagination: PaginationRequest) async throws -> XcodeCloudWorkflowList {
        let service = BagbutikService(jwt: key.jwt)
        let product = try await service.request(.getCiProductForAppV1(id: appID))
        let response = try await service.request(workflowsRequest(productID: product.data.id, pagination: pagination))
        return try .init(appID: appID, workflows: response.data.map(workflow), pagination: BuildService.paginationMetadata(
            limit: pagination.resolvedLimit(), total: response.meta?.paging.total,
            nextCursor: PaginationCursor.extract(from: response.links.next),
        ))
    }

    private static func getWorkflowLive(key: APIKey, workflowID: String) async throws -> XcodeCloudWorkflow {
        let response = try await BagbutikService(jwt: key.jwt).request(.getCiWorkflowV1(id: workflowID, includes: [.repository]))
        return workflow(response.data)
    }

    private static func listGitReferencesLive(key: APIKey, repositoryID: String, pagination: PaginationRequest) async throws -> XcodeCloudGitReferenceList {
        let response = try await BagbutikService(jwt: key.jwt).request(gitReferencesRequest(repositoryID: repositoryID, pagination: pagination))
        return try .init(repositoryID: repositoryID, gitReferences: response.data.map(gitReference), pagination: BuildService.paginationMetadata(
            limit: pagination.resolvedLimit(), total: response.meta?.paging.total,
            nextCursor: PaginationCursor.extract(from: response.links.next),
        ))
    }

    private static func getGitReferenceLive(key: APIKey, gitReferenceID: String) async throws -> XcodeCloudGitReference {
        let response = try await BagbutikService(jwt: key.jwt).request(.getScmGitReferenceV1(id: gitReferenceID, includes: [.repository]))
        return gitReference(response.data)
    }

    private static func startBuildLive(key: APIKey, request: XcodeCloudBuildRequest) async throws -> XcodeCloudBuildRun {
        let response = try await BagbutikService(jwt: key.jwt).request(startBuildRequest(request))
        return buildRun(response.data)
    }

    private static func getBuildRunLive(key: APIKey, buildRunID: String) async throws -> XcodeCloudBuildRun {
        let response = try await BagbutikService(jwt: key.jwt).request(.getCiBuildRunV1(id: buildRunID, includes: [.workflow, .sourceBranchOrTag]))
        return buildRun(response.data)
    }

    static func workflow(_ value: CiWorkflow) -> XcodeCloudWorkflow {
        .init(workflowID: value.id, name: value.attributes?.name ?? value.id,
              repositoryID: value.relationships?.repository?.data?.id,
              isEnabled: value.attributes?.isEnabled, isLockedForEditing: value.attributes?.isLockedForEditing,
              lastModifiedDate: value.attributes?.lastModifiedDate)
    }

    static func gitReference(_ value: ScmGitReference) -> XcodeCloudGitReference {
        .init(gitReferenceID: value.id, name: value.attributes?.name ?? value.id,
              canonicalName: value.attributes?.canonicalName, kind: value.attributes?.kind?.rawValue,
              repositoryID: value.relationships?.repository?.data?.id, isDeleted: value.attributes?.isDeleted)
    }

    static func buildRun(_ value: CiBuildRun) -> XcodeCloudBuildRun {
        .init(buildRunID: value.id, number: value.attributes?.number,
              workflowID: value.relationships?.workflow?.data?.id,
              sourceBranchOrTagID: value.relationships?.sourceBranchOrTag?.data?.id,
              executionProgress: value.attributes?.executionProgress?.rawValue,
              completionStatus: value.attributes?.completionStatus?.rawValue,
              createdDate: value.attributes?.createdDate, startedDate: value.attributes?.startedDate,
              finishedDate: value.attributes?.finishedDate)
    }
}
