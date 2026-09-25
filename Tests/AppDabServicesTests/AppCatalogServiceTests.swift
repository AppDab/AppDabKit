@testable import AppDabServices
import BagbutikAppStoreModels
import BagbutikCore
import ConnectAccounts
import Foundation
import Testing

struct AppCatalogServiceTests {
    @Test func deduplicatesVersionsByPlatformAndStateKeepingNewestRecord() {
        let versions = AppVersion.displayProjection([
            appStoreVersion(id: "older", platform: .iOS, state: .readyForDistribution, version: "1.0", createdDate: 100),
            appStoreVersion(id: "newer", platform: .iOS, state: .readyForDistribution, version: "1.1", createdDate: 200),
            appStoreVersion(id: "replaced", platform: .iOS, state: .replacedWithNewVersion, version: "0.9", createdDate: 50),
            appStoreVersion(id: "mac", platform: .macOS, state: .prepareForSubmission, version: "2.0", createdDate: 300)
        ])

        #expect(versions.map(\.versionID) == ["newer", "mac"])
    }

    @Test func appVersionServiceModelUsesPrettyNames() {
        let version = AppVersion.displayProjection([
            appStoreVersion(id: "version", platform: .iOS, state: .readyForDistribution, version: "1.0", createdDate: 100)
        ])

        #expect(version.first?.platform == "iOS")
        #expect(version.first?.state == "Ready for Distribution")
    }

    @Test func returnsTheUpstreamCursorPageWithoutLocalFilteringOrSlicing() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: {
            [apiKey]
        })
        let service = AppCatalogService(
            accountProvider: provider,
            fetchAppsHandler: { _, pagination in
                #expect(pagination == .init(cursor: "cursor-1", limit: 25))
                return .init(items: [
                    .init(
                        appID: "2",
                        name: "Score Wonders",
                        bundleID: "app.scorewonders",
                        sku: "SCORE",
                        primaryLocale: "en-US",
                        iconURL: nil,
                        contentRightsDeclaration: nil,
                        displayVersions: []
                    )
                ], total: 2, nextCursor: "cursor-2")
            }
        )

        let apps = try await service.listApps(
            accountID: apiKey.id,
            pagination: .init(cursor: "cursor-1", limit: 25)
        )

        #expect(apps.apps.count == 1)
        #expect(apps.apps.first?.appID == "2")
        #expect(apps.pagination == .init(limit: 25, total: 2, nextCursor: "cursor-2"))
        #expect(apps.pagination.hasMore)
    }

    @Test func rejectsAMissingAppStoreConnectPagingTotal() {
        #expect(throws: ServiceError.upstream("App Store Connect did not provide a paging total.")) {
            try AppCatalogService.paginationMetadata(limit: 50, total: nil, nextCursor: "cursor-1")
        }
    }

    @Test func createsVersionsUsingTheRequestedAppAndPlatform() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
        let service = AppCatalogService(
            accountProvider: provider,
            createAppVersionHandler: { receivedKey, appID, platform, version in
                #expect(receivedKey.id == apiKey.id)
                #expect(appID == "app-1")
                #expect(platform == "IOS")
                #expect(version == "2.0")
                return .init(
                    versionID: "version-2",
                    platform: "iOS",
                    state: "Prepare for Submission",
                    version: version,
                    createdDate: Date(timeIntervalSince1970: 200),
                    isFirstVersion: false
                )
            }
        )

        let version = try await service.createAppVersion(
            accountID: apiKey.id,
            appID: "app-1",
            platform: "IOS",
            version: "2.0"
        )

        #expect(version.versionID == "version-2")
    }

    @Test func rejectsUnsupportedCreateVersionPlatformBeforeCallingService() async throws {
        let apiKey = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [apiKey] })
        let service = AppCatalogService(accountProvider: provider)

        await #expect(throws: ServiceError.invalidArguments(
            "Argument platform must be one of \(Platform.allCases.map(\.rawValue).joined(separator: ", "))."
        )) {
            try await service.createAppVersion(
                accountID: apiKey.id,
                appID: "app-1",
                platform: "WATCH_OS",
                version: "2.0"
            )
        }
    }

    private func appStoreVersion(
        id: String,
        platform: Platform,
        state: AppVersionState,
        version: String,
        createdDate: TimeInterval
    ) -> AppStoreVersion {
        AppStoreVersion(
            id: id,
            attributes: .init(
                appVersionState: state,
                createdDate: Date(timeIntervalSince1970: createdDate),
                platform: platform,
                versionString: version
            )
        )
    }
}
