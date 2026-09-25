import AppDabBagbutikExtensions
import BagbutikAppStoreModels
import BagbutikCore
import Foundation

public struct AppVersion: Codable, Equatable, Hashable, Sendable {
    public let versionID: String
    public let platform: String
    public let state: String
    public let version: String
    public let createdDate: Date
    public let isFirstVersion: Bool

    public init(
        versionID: String,
        platform: String,
        state: String,
        version: String,
        createdDate: Date,
        isFirstVersion: Bool
    ) {
        self.versionID = versionID
        self.platform = platform
        self.state = state
        self.version = version
        self.createdDate = createdDate
        self.isFirstVersion = isFirstVersion
    }

    init(appStoreVersion: AppStoreVersion, isFirstVersion: Bool) {
        self.init(
            versionID: appStoreVersion.id,
            platform: (appStoreVersion.attributes?.platform ?? .iOS).prettyName,
            state: (appStoreVersion.attributes?.appVersionState ?? .prepareForSubmission).prettyName,
            version: appStoreVersion.attributes?.versionString ?? "",
            createdDate: appStoreVersion.attributes?.createdDate ?? .distantPast,
            isFirstVersion: isFirstVersion
        )
    }

    static func displayProjection(_ versions: [AppStoreVersion]) -> [Self] {
        let firstVersionCounts = versions.reduce(into: [Platform: Int]()) { counts, version in
            guard let platform = version.attributes?.platform else { return }
            counts[platform, default: 0] += 1
        }
        let normalizedVersions = versions.compactMap { version -> Self? in
            guard version.attributes?.appVersionState != .replacedWithNewVersion else { return nil }
            return Self(
                appStoreVersion: version,
                isFirstVersion: firstVersionCounts[version.attributes?.platform ?? .iOS] == 1
            )
        }
        return normalizedVersions
            .reduce(into: [String: Self]()) { uniqueVersions, version in
                let key = "\(version.platform)-\(version.state)"
                if let currentVersion = uniqueVersions[key], currentVersion.createdDate >= version.createdDate {
                    return
                }
                uniqueVersions[key] = version
            }
            .map(\.value)
            .sorted { lhs, rhs in
                if lhs.platform == rhs.platform {
                    lhs.version < rhs.version
                } else {
                    lhs.platform < rhs.platform
                }
            }
    }
}
