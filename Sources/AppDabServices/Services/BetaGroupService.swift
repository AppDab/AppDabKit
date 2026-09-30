import BagbutikAppStore
import BagbutikAppStoreModels
import BagbutikCore
import BagbutikTestFlight
import BagbutikTestFlightModels
import ConnectAccounts

public final class BetaGroupService: BetaGroupServing, @unchecked Sendable {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    public func listBetaGroups(accountID: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList {
        try pagination.validate()
        guard !appID.isEmpty else { throw ServiceError.invalidArguments("Argument appID must be a nonempty string.") }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let request = try Self.listRequest(appID: appID, pagination: pagination)
            let response = try await service.request(request)
            guard let total = response.meta?.paging.total else {
                throw ServiceError.upstream("App Store Connect did not provide a paging total.")
            }
            return try .init(appID: appID, betaGroups: response.data.map(BetaGroupSummary.init),
                             pagination: .init(limit: pagination.resolvedLimit(), total: total,
                                               nextCursor: PaginationCursor.extract(from: response.links.next)))
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    static func listRequest(appID: String, pagination: PaginationRequest) throws -> Request<BetaGroupsResponse, ErrorResponse> {
        let request: Request<BetaGroupsResponse, ErrorResponse> = try .listBetaGroupsV1(
            filters: [.app([appID])], sorts: [.nameAscending], limits: [.limit(pagination.resolvedLimit())],
        )
        return try request.withPaginationCursor(pagination.validatedCursor())
    }

    public func getBetaGroup(accountID: String, betaGroupID: String) async throws -> BetaGroupSummary {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.getBetaGroupV1(id: betaGroupID))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func createBetaGroup(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.createBetaGroupV1(requestBody: .init(data: .init(
                attributes: .init(hasAccessToAllBuilds: hasAccessToAllBuilds, isInternalGroup: isInternalGroup, name: name),
                relationships: .init(app: .init(data: .init(id: appID))),
            ))))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.updateBetaGroupV1(
                id: betaGroupID, requestBody: Self.updateRequestBody(betaGroupID: betaGroupID, changes: changes),
            ))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    static func updateRequestBody(betaGroupID: String, changes: BetaGroupChanges) -> BetaGroupUpdateRequest {
        .init(data: .init(id: betaGroupID, attributes: .init(
            feedbackEnabled: changes.feedbackEnabled,
            iosBuildsAvailableForAppleSiliconMac: changes.iosBuildsAvailableForAppleSiliconMac,
            iosBuildsAvailableForAppleVision: changes.iosBuildsAvailableForAppleVision,
            name: changes.name,
            publicLinkEnabled: changes.publicLinkEnabled,
            publicLinkLimit: changes.publicLinkLimit,
            publicLinkLimitEnabled: changes.publicLinkLimitEnabled,
        )))
    }

    public func buildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let group = try await service.request(.getBetaGroupV1(id: betaGroupID))
            let matching = try await service.request(Self.membershipRequest(betaGroupID: betaGroupID, buildID: buildID))
            return .init(betaGroup: .init(group.data), buildID: buildID,
                         isMember: matching.data.contains { $0.id == betaGroupID })
        } catch { throw try ServiceError.classify(error) }
    }

    static func membershipRequest(betaGroupID: String, buildID: String) -> Request<BetaGroupsResponse, ErrorResponse> {
        .listBetaGroupsV1(filters: [.id([betaGroupID]), .builds([buildID])], limits: [.limit(1)])
    }

    public func mutateBuildMembership(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let body = BetaGroupBuildsLinkagesRequest(data: [.init(id: buildID)])
            if add {
                _ = try await service.request(.createBuildsForBetaGroupV1(id: betaGroupID, requestBody: body))
            } else {
                _ = try await service.request(.deleteBuildsForBetaGroupV1(id: betaGroupID, requestBody: body))
            }
            let group = try await service.request(.getBetaGroupV1(id: betaGroupID))
            return .init(betaGroup: .init(group.data), buildID: buildID, isMember: add)
        } catch { throw try ServiceError.classify(error) }
    }
}
