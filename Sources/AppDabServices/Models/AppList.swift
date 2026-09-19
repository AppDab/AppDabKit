import Foundation

public struct AppList: Codable, Equatable, Hashable, Sendable {
    public let apps: [AppSummary]
    public let pagination: PaginationMetadata

    public init(apps: [AppSummary], pagination: PaginationMetadata) {
        self.apps = apps
        self.pagination = pagination
    }
}
