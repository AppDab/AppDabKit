import BagbutikCore
import BagbutikTestFlight
import BagbutikTestFlightModels
import ConnectAccounts

public final class BetaGroupTesterService: BetaGroupTesterServing, @unchecked Sendable {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    public func listBetaTesters(accountID: String, scope: BetaTesterScope, pagination: PaginationRequest) async throws -> BetaTesterList {
        try pagination.validate()
        let scopeID: String
        let filter: ListBetaTestersV1.Filter
        switch scope {
        case let .app(id): scopeID = id; filter = .apps([id])
        case let .betaGroup(id): scopeID = id; filter = .betaGroups([id])
        case let .build(id): scopeID = id; filter = .builds([id])
        }
        guard !scopeID.isEmpty else { throw ServiceError.invalidArguments("The tester scope identifier must be nonempty.") }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let request = try Self.listRequest(filter: filter, pagination: pagination)
            let response = try await service.request(request)
            guard let total = response.meta?.paging.total else {
                throw ServiceError.upstream("App Store Connect did not provide a paging total.")
            }
            let testers = response.data.map { tester in
                BetaTesterSummary(tester, betaGroupIDs: tester.relationships?.betaGroups?.data?.map(\.id) ?? [])
            }
            return try .init(scopeID: scopeID, testers: testers, pagination: .init(
                limit: pagination.resolvedLimit(), total: total,
                nextCursor: PaginationCursor.extract(from: response.links.next),
            ))
        } catch { throw try ServiceError.classify(error) }
    }

    static func listRequest(filter: ListBetaTestersV1.Filter, pagination: PaginationRequest) throws -> Request<BetaTestersResponse, ErrorResponse> {
        let limit = try pagination.resolvedLimit()
        let request: Request<BetaTestersResponse, ErrorResponse> = .listBetaTestersV1(
            fields: [.betaTesters([.email, .firstName, .lastName, .inviteType, .state, .betaGroups])],
            filters: [filter, .inviteType([.email])],
            includes: [.betaGroups],
            sorts: [.emailAscending],
            limits: [.limit(limit)],
        )
        return try request.withPaginationCursor(pagination.validatedCursor())
    }

    public func inviteBetaTester(accountID: String, email: String, firstName: String?, lastName: String?, destination: BetaTesterDestination) async throws -> BetaTesterSummary {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidArguments("Argument email must be nonempty.")
        }
        let relationships: BetaTesterCreateRequest.Data.Relationships
        switch destination {
        case let .betaGroup(id):
            guard !id.isEmpty else { throw ServiceError.invalidArguments("Argument betaGroupID must be nonempty.") }
            relationships = .init(betaGroups: .init(data: [.init(id: id)]))
        case let .build(id):
            guard !id.isEmpty else { throw ServiceError.invalidArguments("Argument buildID must be nonempty.") }
            relationships = .init(builds: .init(data: [.init(id: id)]))
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.createBetaTesterV1(requestBody: .init(data: .init(
                attributes: .init(email: email, firstName: firstName, lastName: lastName),
                relationships: relationships,
            ))))
            let attributes = response.data.attributes
            return .init(betaTesterID: response.data.id, email: attributes?.email ?? email,
                         firstName: attributes?.firstName ?? firstName, lastName: attributes?.lastName ?? lastName,
                         inviteType: attributes?.inviteType?.rawValue, state: "INVITED",
                         betaGroupIDs: response.data.relationships?.betaGroups?.data?.map(\.id) ?? [])
        } catch { throw try ServiceError.classify(error) }
    }

    public func sendBetaTesterInvitation(accountID: String, appID: String, testerID: String) async throws -> BetaTesterSummary {
        guard !appID.isEmpty, !testerID.isEmpty else {
            throw ServiceError.invalidArguments("App and beta tester identifiers must be nonempty.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let testerResponse = try await service.request(.getBetaTesterV1(
                id: testerID,
                fields: [.betaTesters([.email, .firstName, .lastName, .inviteType, .state, .betaGroups])],
            ))
            guard testerResponse.data.attributes?.inviteType == .email else {
                throw ServiceError.invalidArguments("Only email beta testers can be invited.")
            }
            if testerResponse.data.attributes?.state != .notInvited {
                return .init(testerResponse.data, betaGroupIDs: testerResponse.data.relationships?.betaGroups?.data?.map(\.id) ?? [])
            }
            _ = try await service.request(.createBetaTesterInvitationV1(requestBody: .init(data: .init(
                relationships: .init(
                    app: .init(data: .init(id: appID)),
                    betaTester: .init(data: .init(id: testerID)),
                ),
            ))))
            return .init(betaTesterID: testerID,
                         email: testerResponse.data.attributes?.email ?? "",
                         firstName: testerResponse.data.attributes?.firstName,
                         lastName: testerResponse.data.attributes?.lastName,
                         inviteType: testerResponse.data.attributes?.inviteType?.rawValue,
                         state: "INVITED",
                         betaGroupIDs: testerResponse.data.relationships?.betaGroups?.data?.map(\.id) ?? [])
        } catch { throw try ServiceError.classify(error) }
    }

    public func membership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let group = try await service.request(.getBetaGroupV1(id: betaGroupID))
            let testers = try await service.request(Self.membershipRequest(betaGroupID: betaGroupID, testerID: testerID))
            return .init(
                betaGroupID: betaGroupID,
                betaGroupName: group.data.attributes?.name ?? betaGroupID,
                testerID: testerID,
                isMember: testers.data.contains { $0.id == testerID },
            )
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    public func mutate(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        let testerID: String
        let isMember: Bool
        do {
            switch mutation {
            case let .add(id):
                testerID = id
                isMember = true
                _ = try await service.request(.createBetaTestersForBetaGroupV1(
                    id: betaGroupID,
                    requestBody: .init(data: [.init(id: id)]),
                ))
            case let .remove(id):
                testerID = id
                isMember = false
                _ = try await service.request(.deleteBetaTestersForBetaGroupV1(
                    id: betaGroupID,
                    requestBody: .init(data: [.init(id: id)]),
                ))
            }
            let group = try await service.request(.getBetaGroupV1(id: betaGroupID))
            return .init(
                betaGroupID: betaGroupID,
                betaGroupName: group.data.attributes?.name ?? betaGroupID,
                testerID: testerID,
                isMember: isMember,
            )
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    static func membershipRequest(betaGroupID: String, testerID: String) -> Request<BetaTestersResponse, ErrorResponse> {
        .listBetaTestersV1(filters: [.betaGroups([betaGroupID]), .id([testerID])], limits: [.limit(1)])
    }
}
