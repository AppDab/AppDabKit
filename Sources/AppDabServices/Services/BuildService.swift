import BagbutikAppStoreModels
import BagbutikCore
import ConnectAccounts

public final class BuildService: BuildServing, @unchecked Sendable {
    public typealias ListBuildsHandler = @Sendable (APIKey, String, PaginationRequest) async throws -> BuildList
    public typealias GetBuildHandler = @Sendable (APIKey, String) async throws -> BuildSummary
    private let listBuildsHandler: ListBuildsHandler?
    private let getBuildHandler: GetBuildHandler

    private let accountProvider: any APIKeyProviding

    public init(
        accountProvider: any APIKeyProviding,
        listBuildsHandler: ListBuildsHandler? = nil,
        getBuildHandler: GetBuildHandler? = nil,
    ) {
        self.accountProvider = accountProvider
        self.listBuildsHandler = listBuildsHandler
        self.getBuildHandler = getBuildHandler ?? Self.getBuildLive
    }

    public func listBuilds(accountID: String, appID: String, pagination: PaginationRequest = .init()) async throws -> BuildList {
        try await listBuilds(accountID: accountID, appID: appID, pagination: pagination, sort: .uploadedDate)
    }

    public func listBuilds(accountID: String, appID: String, pagination: PaginationRequest, sort: BuildListSort) async throws -> BuildList {
        try pagination.validate()
        guard !appID.isEmpty else { throw ServiceError.invalidArguments("Argument appID must be a nonempty string.") }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            if let listBuildsHandler {
                guard sort == .uploadedDate else {
                    throw ServiceError.invalidArguments("This build service does not support version sorting.")
                }
                return try await listBuildsHandler(key, appID, pagination)
            }
            return try await Self.listBuildsLive(key: key, appID: appID, pagination: pagination, sort: sort)
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    public func getBuild(accountID: String, buildID: String) async throws -> BuildSummary {
        guard !buildID.isEmpty else { throw ServiceError.invalidArguments("Argument buildID must be a nonempty string.") }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            return try await getBuildHandler(key, buildID)
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    static func buildsRequest(
        appID: String, pagination: PaginationRequest, sort: BuildListSort = .uploadedDate,
    ) throws -> Request<BuildsResponse, ErrorResponse> {
        let request: Request<BuildsResponse, ErrorResponse> = try .listBuildsV1(
            filters: [.app([appID])],
            includes: [.preReleaseVersion, .buildBetaDetail],
            sorts: sort == .version ? [.preReleaseVersionDescending, .versionDescending] : [.uploadedDateDescending],
            limits: [.limit(pagination.resolvedLimit())],
        )
        return try request.withPaginationCursor(pagination.validatedCursor())
    }

    private static func listBuildsLive(key: APIKey, appID: String, pagination: PaginationRequest, sort: BuildListSort) async throws -> BuildList {
        let service = BagbutikService(jwt: key.jwt)
        let response = try await service.request(buildsRequest(appID: appID, pagination: pagination, sort: sort))
        return try .init(
            appID: appID,
            builds: response.data.map { build in
                let version = response.getPreReleaseVersion(for: build)?.attributes
                return BuildSummary(
                    build: build,
                    platform: version?.platform?.prettyName,
                    prereleaseVersion: version?.version,
                    externalBetaState: response.getBuildBetaDetail(for: build)?.attributes?.externalBuildState?.rawValue,
                )
            },
            pagination: paginationMetadata(
                limit: pagination.resolvedLimit(),
                total: response.meta?.paging.total,
                nextCursor: PaginationCursor.extract(from: response.links.next),
            ),
        )
    }

    private static func getBuildLive(key: APIKey, buildID: String) async throws -> BuildSummary {
        let service = BagbutikService(jwt: key.jwt)
        let response = try await service.request(.getBuildV1(id: buildID, includes: [.preReleaseVersion]))
        return .init(
            build: response.data,
            platform: response.getPreReleaseVersion()?.attributes?.platform?.prettyName,
        )
    }

    static func paginationMetadata(
        limit: Int,
        total: Int?,
        nextCursor: String?,
    ) throws -> PaginationMetadata {
        guard let total else {
            throw ServiceError.upstream("App Store Connect did not provide a paging total.")
        }
        return .init(limit: limit, total: total, nextCursor: nextCursor)
    }
}
