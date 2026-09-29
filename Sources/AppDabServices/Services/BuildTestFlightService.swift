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

    public func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        guard !buildID.isEmpty else {
            throw ServiceError.invalidArguments("Argument buildID must be a nonempty string.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let response = try await service.request(.getBuildV1(
                id: buildID,
                includes: [.preReleaseVersion, .buildBetaDetail, .betaAppReviewSubmission]
            ))
            let testerIDs: [String]
            let betaGroupIDs: [String]
            switch scope {
            case .build:
                testerIDs = []
                betaGroupIDs = []
            case .individualTester(let targetID):
                var page = try await service.request(.listIndividualTesterIdsForBuildV1(id: buildID, limit: 200))
                var found = page.data.contains { $0.id == targetID }
                while !found, let next = try await service.requestNextPage(for: page) {
                    page = next
                    found = page.data.contains { $0.id == targetID }
                }
                testerIDs = found ? [targetID] : []
                betaGroupIDs = []
            case .betaGroup(let targetID):
                var page = try await service.request(
                    .listBetaGroupsV1(filters: [.builds([buildID])], limits: [.limit(200)])
                )
                var found = page.data.contains { $0.id == targetID }
                while !found, let next = try await service.requestNextPage(for: page) {
                    page = next
                    found = page.data.contains { $0.id == targetID }
                }
                testerIDs = []
                betaGroupIDs = found ? [targetID] : []
            }
            return .init(
                build: .init(
                    build: response.data,
                    platform: response.getPreReleaseVersion()?.attributes?.platform?.prettyName
                ),
                individualTesterIDs: testerIDs,
                betaGroupIDs: betaGroupIDs,
                betaReviewSubmissionID: response.data.relationships?.betaAppReviewSubmission?.data?.id,
                externalBetaState: response.getBuildBetaDetail()?.attributes?.externalBuildState?.rawValue,
                autoNotifyEnabled: response.getBuildBetaDetail()?.attributes?.autoNotifyEnabled
            )
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    public func mutateBuild(
        accountID: String,
        buildID: String,
        mutation: BuildTestFlightMutation
    ) async throws -> BuildSummary {
        guard !buildID.isEmpty else {
            throw ServiceError.invalidArguments("Argument buildID must be a nonempty string.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            switch mutation {
            case .addIndividualTesters(let testerIDs):
                try await service.request(.createIndividualTestersForBuildV1(
                    id: buildID,
                    requestBody: .init(data: testerIDs.map(BuildIndividualTestersLinkagesRequest.Data.init(id:)))
                ))
            case .removeIndividualTesters(let testerIDs):
                try await service.request(.deleteIndividualTestersForBuildV1(
                    id: buildID,
                    requestBody: .init(data: testerIDs.map(BuildIndividualTestersLinkagesRequest.Data.init(id:)))
                ))
            case .addBetaGroups(let betaGroupIDs):
                try await service.request(.createBetaGroupsForBuildV1(
                    id: buildID,
                    requestBody: .init(data: betaGroupIDs.map(BuildBetaGroupsLinkagesRequest.Data.init(id:)))
                ))
            case .removeBetaGroups(let betaGroupIDs):
                try await service.request(.deleteBetaGroupsForBuildV1(
                    id: buildID,
                    requestBody: .init(data: betaGroupIDs.map(BuildBetaGroupsLinkagesRequest.Data.init(id:)))
                ))
            case .submitForBetaReview(let autoNotifyEnabled):
                let build = try await service.request(.getBuildV1(id: buildID))
                guard let detailID = build.data.relationships?.buildBetaDetail?.data?.id else {
                    throw ServiceError.invalidArguments("Build has no beta detail to submit.")
                }
                _ = try await service.request(.updateBuildBetaDetailV1(
                    id: detailID,
                    requestBody: .init(data: .init(
                        id: detailID,
                        attributes: .init(autoNotifyEnabled: autoNotifyEnabled)
                    ))
                ))
                _ = try await service.request(.createBetaAppReviewSubmissionV1(
                    requestBody: .init(data: .init(relationships: .init(build: .init(data: .init(id: buildID)))))
                ))
            case .expire:
                _ = try await service.request(.updateBuildV1(
                    id: buildID,
                    requestBody: .init(data: .init(id: buildID, attributes: .init(expired: true)))
                ))
            }
            let response = try await service.request(.getBuildV1(id: buildID, includes: [.preReleaseVersion]))
            return .init(build: response.data, platform: response.getPreReleaseVersion()?.attributes?.platform?.prettyName)
        } catch {
            throw try ServiceError.classify(error)
        }
    }
}
