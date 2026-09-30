import BagbutikCore
import BagbutikTestFlight
import BagbutikTestFlightModels
import ConnectAccounts

public final class BetaGroupTesterService: BetaGroupTesterServing, @unchecked Sendable {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
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
