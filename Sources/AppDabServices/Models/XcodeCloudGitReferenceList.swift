import Foundation

public struct XcodeCloudGitReferenceList: Codable, Equatable, Sendable {
    public let repositoryID: String
    public let gitReferences: [XcodeCloudGitReference]
    public let pagination: PaginationMetadata

    public init(repositoryID: String, gitReferences: [XcodeCloudGitReference], pagination: PaginationMetadata) {
        self.repositoryID = repositoryID
        self.gitReferences = gitReferences
        self.pagination = pagination
    }
}
