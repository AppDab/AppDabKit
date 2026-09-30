import BagbutikAppStore
import BagbutikCore
import BagbutikTestFlight
import BagbutikTestFlightModels
import ConnectAccounts

public final class BuildTestFlightService: BuildTestFlightServing, @unchecked Sendable {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    public func getBetaBuildLocalization(accountID: String, localizationID: String) async throws -> BetaBuildLocalizationSummary {
        guard !localizationID.isEmpty else { throw ServiceError.invalidArguments("Argument localizationID must be nonempty.") }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.getBetaBuildLocalizationV1(id: localizationID))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func updateBetaBuildLocalization(accountID: String, localizationID: String, whatsNew: String) async throws -> BetaBuildLocalizationSummary {
        guard !localizationID.isEmpty else { throw ServiceError.invalidArguments("Argument localizationID must be nonempty.") }
        guard whatsNew.count <= 4000 else { throw ServiceError.invalidArguments("Argument whatsNew must be at most 4000 characters.") }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.updateBetaBuildLocalizationV1(
                id: localizationID,
                requestBody: .init(data: .init(id: localizationID, attributes: .init(whatsNew: whatsNew))),
            ))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        guard !buildID.isEmpty else {
            throw ServiceError.invalidArguments("Argument buildID must be a nonempty string.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.getBuildV1(
                id: buildID,
                includes: [.preReleaseVersion, .buildBetaDetail, .betaAppReviewSubmission],
            ))
            let testerIDs: [String]
            let betaGroupIDs: [String]
            switch scope {
            case .build:
                testerIDs = []
                betaGroupIDs = []
            case let .individualTester(targetID):
                let matchingTesters = try await service.request(Self.testerMembershipRequest(buildID: buildID, testerID: targetID))
                testerIDs = matchingTesters.data.contains { $0.id == targetID } ? [targetID] : []
                betaGroupIDs = []
            case let .betaGroup(targetID):
                let matchingGroups = try await service.request(Self.groupMembershipRequest(buildID: buildID, groupID: targetID))
                testerIDs = []
                betaGroupIDs = matchingGroups.data.contains { $0.id == targetID } ? [targetID] : []
            }
            return .init(
                build: .init(
                    build: response.data,
                    platform: response.getPreReleaseVersion()?.attributes?.platform?.prettyName,
                ),
                individualTesterIDs: testerIDs,
                betaGroupIDs: betaGroupIDs,
                betaReviewSubmissionID: response.data.relationships?.betaAppReviewSubmission?.data?.id,
                externalBetaState: response.getBuildBetaDetail()?.attributes?.externalBuildState?.rawValue,
                autoNotifyEnabled: response.getBuildBetaDetail()?.attributes?.autoNotifyEnabled,
            )
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    static func testerMembershipRequest(buildID: String, testerID: String) -> Request<BetaTestersResponse, ErrorResponse> {
        .listBetaTestersV1(filters: [.builds([buildID]), .id([testerID])], limits: [.limit(1)])
    }

    static func groupMembershipRequest(buildID: String, groupID: String) -> Request<BetaGroupsResponse, ErrorResponse> {
        .listBetaGroupsV1(filters: [.builds([buildID]), .id([groupID])], limits: [.limit(1)])
    }

    public func mutateBuild(
        accountID: String,
        buildID: String,
        mutation: BuildTestFlightMutation,
    ) async throws -> BuildSummary {
        guard !buildID.isEmpty else {
            throw ServiceError.invalidArguments("Argument buildID must be a nonempty string.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            switch mutation {
            case let .addIndividualTesters(testerIDs):
                try await service.request(.createIndividualTestersForBuildV1(
                    id: buildID,
                    requestBody: .init(data: testerIDs.map(BuildIndividualTestersLinkagesRequest.Data.init(id:))),
                ))
            case let .removeIndividualTesters(testerIDs):
                try await service.request(.deleteIndividualTestersForBuildV1(
                    id: buildID,
                    requestBody: .init(data: testerIDs.map(BuildIndividualTestersLinkagesRequest.Data.init(id:))),
                ))
            case let .addBetaGroups(betaGroupIDs):
                try await service.request(.createBetaGroupsForBuildV1(
                    id: buildID,
                    requestBody: .init(data: betaGroupIDs.map(BuildBetaGroupsLinkagesRequest.Data.init(id:))),
                ))
            case let .removeBetaGroups(betaGroupIDs):
                try await service.request(.deleteBetaGroupsForBuildV1(
                    id: buildID,
                    requestBody: .init(data: betaGroupIDs.map(BuildBetaGroupsLinkagesRequest.Data.init(id:))),
                ))
            case let .submitForBetaReview(autoNotifyEnabled):
                let build = try await service.request(.getBuildV1(id: buildID))
                guard let detailID = build.data.relationships?.buildBetaDetail?.data?.id else {
                    throw ServiceError.invalidArguments("Build has no beta detail to submit.")
                }
                _ = try await service.request(.updateBuildBetaDetailV1(
                    id: detailID,
                    requestBody: .init(data: .init(
                        id: detailID,
                        attributes: .init(autoNotifyEnabled: autoNotifyEnabled),
                    )),
                ))
                _ = try await service.request(.createBetaAppReviewSubmissionV1(
                    requestBody: .init(data: .init(relationships: .init(build: .init(data: .init(id: buildID))))),
                ))
            case .expire:
                _ = try await service.request(.updateBuildV1(
                    id: buildID,
                    requestBody: .init(data: .init(id: buildID, attributes: .init(expired: true))),
                ))
            }
            let response = try await service.request(.getBuildV1(id: buildID, includes: [.preReleaseVersion]))
            return .init(build: response.data, platform: response.getPreReleaseVersion()?.attributes?.platform?.prettyName)
        } catch {
            throw try ServiceError.classify(error)
        }
    }
}
