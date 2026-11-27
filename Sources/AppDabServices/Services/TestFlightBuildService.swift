import BagbutikAppStore
import BagbutikAppStoreModels
import BagbutikCore
import BagbutikModelsShared
import BagbutikTestFlightModels
import ConnectAccounts
import Foundation

public struct TestFlightBuild: Codable, Equatable, Sendable {
    public let id: String
    public let buildNumber: String?
    public let version: String?
    public let platform: String?
    public let iconURL: URL?
    public let externalState: String?
    public let processingState: String?

    public init(
        id: String,
        buildNumber: String?,
        version: String?,
        platform: String?,
        iconURL: URL?,
        externalState: String?,
        processingState: String?,
    ) {
        self.id = id
        self.buildNumber = buildNumber
        self.version = version
        self.platform = platform
        self.iconURL = iconURL
        self.externalState = externalState
        self.processingState = processingState
    }
}

public struct TestFlightBuildDetail: Codable, Equatable, Sendable {
    public struct Localization: Codable, Equatable, Sendable {
        public let id: String
        public let locale: String?
        public let whatToTest: String?

        public init(id: String, locale: String?, whatToTest: String?) {
            self.id = id
            self.locale = locale
            self.whatToTest = whatToTest
        }
    }

    public struct Bundle: Codable, Equatable, Sendable {
        public let id: String
        public let bundleID: String?
        public let bundleType: String?
        public let sdkBuild: String?
        public let platformBuild: String?
        public let fileName: String?
        public let minimumOSVersion: String?
        public let hasOnDemandResources: Bool?
        public let includesSymbols: Bool?
        public let hasSiriKit: Bool?
        public let entitlements: [String: [String: String]]

        public init(
            id: String,
            bundleID: String?,
            bundleType: String?,
            sdkBuild: String?,
            platformBuild: String?,
            fileName: String?,
            minimumOSVersion: String?,
            hasOnDemandResources: Bool?,
            includesSymbols: Bool?,
            hasSiriKit: Bool?,
            entitlements: [String: [String: String]],
        ) {
            self.id = id
            self.bundleID = bundleID
            self.bundleType = bundleType
            self.sdkBuild = sdkBuild
            self.platformBuild = platformBuild
            self.fileName = fileName
            self.minimumOSVersion = minimumOSVersion
            self.hasOnDemandResources = hasOnDemandResources
            self.includesSymbols = includesSymbols
            self.hasSiriKit = hasSiriKit
            self.entitlements = entitlements
        }
    }

    public let appID: String
    public let build: TestFlightBuild
    public let internalState: String?
    public let uploadedDate: Date?
    public let expirationDate: Date?
    public let localizations: [Localization]
    public let bundles: [Bundle]

    public init(
        appID: String,
        build: TestFlightBuild,
        internalState: String?,
        uploadedDate: Date?,
        expirationDate: Date?,
        localizations: [Localization],
        bundles: [Bundle],
    ) {
        self.appID = appID
        self.build = build
        self.internalState = internalState
        self.uploadedDate = uploadedDate
        self.expirationDate = expirationDate
        self.localizations = localizations
        self.bundles = bundles
    }
}

public protocol TestFlightBuildServing: Sendable {
    func getBuild(accountID: String, buildID: String) async throws -> TestFlightBuildDetail
}

public struct TestFlightBuildService: TestFlightBuildServing {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    public func getBuild(accountID: String, buildID: String) async throws -> TestFlightBuildDetail {
        guard !buildID.isEmpty else {
            throw ServiceError.invalidArguments("Argument buildID must be a nonempty string.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            let response = try await BagbutikService(jwt: key.jwt).request(.getBuildV1(
                id: buildID,
                includes: [.app, .preReleaseVersion, .buildBetaDetail, .betaBuildLocalizations, .buildBundles],
                limits: [.betaBuildLocalizations(50), .buildBundles(50)],
            ))
            return try Self.detail(response)
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    static func detail(_ response: BuildResponse) throws -> TestFlightBuildDetail {
        let build = response.data
        guard let appID = build.relationships?.app?.data?.id ?? response.getApp()?.id, !appID.isEmpty else {
            throw ServiceError.upstream("App Store Connect did not return the build’s app.")
        }
        let betaDetail = response.getBuildBetaDetail()
        return .init(
            appID: appID,
            build: summary(build, version: response.getPreReleaseVersion(), betaDetail: betaDetail),
            internalState: betaDetail?.attributes?.internalBuildState?.rawValue,
            uploadedDate: build.attributes?.uploadedDate,
            expirationDate: build.attributes?.expirationDate,
            localizations: response.getBetaBuildLocalizations().map {
                .init(id: $0.id, locale: $0.attributes?.locale, whatToTest: $0.attributes?.whatsNew)
            },
            bundles: response.getBuildBundles().map { bundle in
                let attributes = bundle.attributes
                return .init(
                    id: bundle.id, bundleID: attributes?.bundleId, bundleType: attributes?.bundleType?.rawValue,
                    sdkBuild: attributes?.sdkBuild, platformBuild: attributes?.platformBuild,
                    fileName: attributes?.fileName, minimumOSVersion: attributes?.minimumOsVersion,
                    hasOnDemandResources: attributes?.hasOnDemandResources, includesSymbols: attributes?.includesSymbols,
                    hasSiriKit: attributes?.hasSirikit, entitlements: attributes?.entitlements ?? [:],
                )
            },
        )
    }

    private static func summary(_ build: Build, version: PrereleaseVersion?, betaDetail: BuildBetaDetail?) -> TestFlightBuild {
        .init(
            id: build.id, buildNumber: build.attributes?.version, version: version?.attributes?.version,
            platform: version?.attributes?.platform?.rawValue, iconURL: build.attributes?.iconAssetToken?.url,
            externalState: betaDetail?.attributes?.externalBuildState?.rawValue,
            processingState: build.attributes?.processingState?.rawValue,
        )
    }
}
