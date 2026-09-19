import Foundation

public struct AppSummary: Codable, Equatable, Hashable, Sendable {
    public let appID: String
    public let name: String
    public let bundleID: String
    public let sku: String
    public let primaryLocale: String
    public let iconURL: URL?
    public let versions: [AppVersion]

    public init(
        appID: String,
        name: String,
        bundleID: String,
        sku: String,
        primaryLocale: String,
        iconURL: URL?,
        versions: [AppVersion]
    ) {
        self.appID = appID
        self.name = name
        self.bundleID = bundleID
        self.sku = sku
        self.primaryLocale = primaryLocale
        self.iconURL = iconURL
        self.versions = versions
    }

    init(detail: AppDetail) {
        self.init(
            appID: detail.appID,
            name: detail.name,
            bundleID: detail.bundleID,
            sku: detail.sku,
            primaryLocale: detail.primaryLocale,
            iconURL: detail.iconURL,
            versions: detail.versions
        )
    }
}
