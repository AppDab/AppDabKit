import BagbutikCore
import BagbutikAppStore
import BagbutikAppStoreModels
import ConnectAccounts
import Foundation

public final class AppCatalogService: AppCatalogServing, @unchecked Sendable {
    public typealias FetchAppsHandler = @Sendable (APIKey, PaginationRequest) async throws -> CursorPage<AppDetail>
    public typealias FetchAppHandler = @Sendable (APIKey, String) async throws -> AppDetail
    public typealias CreateAppVersionHandler = @Sendable (APIKey, String, String, String) async throws -> AppVersion

    private let accountProvider: any APIKeyProviding
    private let fetchAppsHandler: FetchAppsHandler
    private let fetchAppHandler: FetchAppHandler
    private let createAppVersionHandler: CreateAppVersionHandler
    private static let interestingStates: [AppStoreVersionState] = {
        var states = AppStoreVersionState.allCases
        states.removeAll(where: { $0 == .replacedWithNewVersion })
        return states
    }()

    public init(
        accountProvider: any APIKeyProviding,
        fetchAppsHandler: FetchAppsHandler? = nil,
        fetchAppHandler: FetchAppHandler? = nil,
        createAppVersionHandler: CreateAppVersionHandler? = nil
    ) {
        self.accountProvider = accountProvider
        self.fetchAppsHandler = fetchAppsHandler ?? Self.fetchAppsLive
        self.fetchAppHandler = fetchAppHandler ?? Self.fetchAppLive
        self.createAppVersionHandler = createAppVersionHandler ?? Self.createAppVersionLive
    }

    public func listApps(
        accountID: String,
        pagination: PaginationRequest = .init()
    ) async throws -> AppList {
        try pagination.validate()
        let limit = try pagination.resolvedLimit()
        let page = try await fetchApps(accountID: accountID, pagination: pagination)
        return .init(
            apps: page.items.map(AppSummary.init(detail:)),
            pagination: .init(limit: limit, total: page.total, nextCursor: page.nextCursor)
        )
    }

    public func getApp(accountID: String, appID: String) async throws -> AppDetail {
        try await fetchApp(accountID: accountID, appID: appID)
    }

    public func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion {
        guard Platform(rawValue: platform) != nil else {
            throw ServiceError.invalidArguments(
                "Argument platform must be one of \(Platform.allCases.map(\.rawValue).joined(separator: ", "))."
            )
        }
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidArguments("Argument version must be a nonempty string.")
        }
        let apiKey = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            return try await createAppVersionHandler(apiKey, appID, platform, version)
        } catch {
            throw Self.mapCreateVersionError(error)
        }
    }

    private func fetchApps(accountID: String, pagination: PaginationRequest) async throws -> CursorPage<AppDetail> {
        let apiKey = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            return try await fetchAppsHandler(apiKey, pagination)
        } catch {
            throw Self.mapUpstream(error)
        }
    }

    private func fetchApp(accountID: String, appID: String) async throws -> AppDetail {
        let apiKey = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            return try await fetchAppHandler(apiKey, appID)
        } catch {
            if Self.looksLikeNotFound(error) {
                throw ServiceError.appNotFound(appID)
            }
            throw Self.mapUpstream(error)
        }
    }

    private static func fetchAppsLive(
        apiKey: APIKey,
        pagination: PaginationRequest
    ) async throws -> CursorPage<AppDetail> {
        let limit = try pagination.resolvedLimit()
        let service = BagbutikService(jwt: apiKey.jwt)
        let response: AppsResponse
        response = try await service.request(appsRequest(limit: limit, cursor: try pagination.validatedCursor()))
        let nextCursor = try PaginationCursor.extract(from: response.links.next)
        return .init(
            items: response.data.map { app in
                let iconAsset = response.getAppStoreIcon(for: app)?.attributes?.iconAsset
                let versions = response.getAppStoreVersions(for: app)
                return AppDetail(app: app, iconAsset: iconAsset, versions: versions)
            },
            total: try paginationMetadata(
                limit: limit,
                total: response.meta?.paging.total,
                nextCursor: nextCursor
            ).total,
            nextCursor: nextCursor
        )
    }

    static func paginationMetadata(
        limit: Int,
        total: Int?,
        nextCursor: String?
    ) throws -> PaginationMetadata {
        guard let total else {
            throw ServiceError.upstream("App Store Connect did not provide a paging total.")
        }
        return .init(limit: limit, total: total, nextCursor: nextCursor)
    }

    private static func appsRequest(limit: Int, cursor: String?) -> Request<AppsResponse, ErrorResponse> {
        let request: Request<AppsResponse, ErrorResponse> = .listAppsV1(
            filters: [.appStoreVersions_appStoreState(Self.interestingStates)],
            includes: [.appStoreIcon, .appStoreVersions],
            sorts: [.nameAscending],
            limits: [.limit(limit), .appStoreVersions(50)]
        )
        return request.withPaginationCursor(cursor)
    }

    private static func fetchAppLive(apiKey: APIKey, appID: String) async throws -> AppDetail {
        let service = BagbutikService(jwt: apiKey.jwt)
        let appResponse = try await service.request(
            .getAppV1(
                id: appID,
                includes: [.appStoreIcon, .appStoreVersions],
                limits: [.appStoreVersions(50)]
            )
        )
        let iconAsset = appResponse.getAppStoreIcon()?.attributes?.iconAsset
        let versions = appResponse.getAppStoreVersions()
        return AppDetail(app: appResponse.data, iconAsset: iconAsset, versions: versions)
    }

    private static func createAppVersionLive(
        apiKey: APIKey,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion {
        guard let platform = Platform(rawValue: platform) else {
            throw ServiceError.invalidArguments(
                "Argument platform must be one of \(Platform.allCases.map(\.rawValue).joined(separator: ", "))."
            )
        }
        let service = BagbutikService(jwt: apiKey.jwt)
        let versions = try await service.request(
            .listAppStoreVersionsForAppV1(
                id: appID,
                filters: [.platform([platform])],
                limits: [.limit(0)]
            )
        )
        let response = try await service.request(
            .createAppStoreVersionV1(
                requestBody: .init(data: .init(
                    attributes: .init(platform: platform, versionString: version),
                    relationships: .init(app: .init(data: .init(id: appID)))
                ))
            )
        )
        return .init(
            appStoreVersion: response.data,
            isFirstVersion: versions.meta?.paging.total == 0
        )
    }

    private static func mapUpstream(_ error: Error) -> ServiceError {
        ServiceError.classify(error)
    }

    private static func mapCreateVersionError(_ error: Error) -> ServiceError {
        guard let error = error as? BagbutikCore.ServiceError,
              case .conflict(let errorResponse) = error,
              let ascError = errorResponse.errors?.first,
              ascError.status == "409",
              ascError.code == "ENTITY_ERROR.RELATIONSHIP.INVALID",
              let source = ascError.source,
              case .jsonPointer(let jsonPointer) = source,
              jsonPointer.pointer == "/data/relationships/app" else {
            return mapUpstream(error)
        }
        return .invalidArguments(
            "Apple does not allow creating a new version for this platform until the current version is ready for distribution."
        )
    }

    private static func looksLikeNotFound(_ error: Error) -> Bool {
        let loweredDescription = error.localizedDescription.lowercased()
        return loweredDescription.contains("404")
            || loweredDescription.contains("not found")
    }
}
