import BagbutikAppStore
import BagbutikAppStoreModels
import BagbutikCore
import BagbutikModelsShared
import Foundation

public struct AppDetail: Codable, Equatable, Hashable, Sendable {
    public let appID: String
    public let name: String
    public let bundleID: String
    public let sku: String
    public let primaryLocale: String
    public let iconURL: URL?
    public let contentRightsDeclaration: String?
    /// A reduced display projection, not an authoritative version collection.
    public let displayVersions: [AppVersion]

    private enum CodingKeys: String, CodingKey {
        case appID
        case name
        case bundleID
        case sku
        case primaryLocale
        case iconURL
        case contentRightsDeclaration
        // Keep the public response compatible while making the in process API
        // explicit about this being a display only projection.
        case displayVersions = "versions"
    }

    public init(
        appID: String,
        name: String,
        bundleID: String,
        sku: String,
        primaryLocale: String,
        iconURL: URL?,
        contentRightsDeclaration: String?,
        displayVersions: [AppVersion]
    ) {
        self.appID = appID
        self.name = name
        self.bundleID = bundleID
        self.sku = sku
        self.primaryLocale = primaryLocale
        self.iconURL = iconURL
        self.contentRightsDeclaration = contentRightsDeclaration
        self.displayVersions = displayVersions
    }

    init(app: App, iconAsset: ImageAsset?, versions: [AppStoreVersion]) {
        self.init(
            appID: app.id,
            name: app.attributes?.name ?? "",
            bundleID: app.attributes?.bundleId ?? "",
            sku: app.attributes?.sku ?? "",
            primaryLocale: app.attributes?.primaryLocale ?? "",
            iconURL: iconAsset.flatMap { $0.getImageUrl() },
            contentRightsDeclaration: app.attributes?.contentRightsDeclaration.map(String.init(describing:)),
            displayVersions: AppVersion.displayProjection(versions)
        )
    }
}

private extension ImageAsset {
    func getImageUrl() -> URL? {
        guard let templateURL = templateUrl else { return nil }
        return URL(string: templateURL
            .replacingOccurrences(of: "{w}", with: width.map { "\($0)" } ?? "1024")
            .replacingOccurrences(of: "{h}", with: height.map { "\($0)" } ?? "1024")
            .replacingOccurrences(of: "{c}", with: "bb")
            .replacingOccurrences(of: "{f}", with: "png"))
    }
}
