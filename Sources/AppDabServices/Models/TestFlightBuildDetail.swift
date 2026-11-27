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

    public let appID: String?
    public let localizations: [Localization]
    public let bundles: [Bundle]

    public init(
        appID: String?,
        localizations: [Localization],
        bundles: [Bundle],
    ) {
        self.appID = appID
        self.localizations = localizations
        self.bundles = bundles
    }
}
