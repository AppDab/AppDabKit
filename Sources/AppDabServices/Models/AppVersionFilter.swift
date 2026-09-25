import BagbutikCore
import BagbutikAppStoreModels

/// Server side filters for authoritative version reads. Empty arrays mean no filter.
public struct AppVersionFilter: Codable, Sendable, Equatable {
    public let platforms: [Platform]
    public let states: [AppVersionState]
    public let versions: [String]
    public let versionIDs: [String]

    public init(platforms: [Platform] = [], states: [AppVersionState] = [], versions: [String] = [], versionIDs: [String] = []) {
        self.platforms = platforms
        self.states = states
        self.versions = versions
        self.versionIDs = versionIDs
    }
}
