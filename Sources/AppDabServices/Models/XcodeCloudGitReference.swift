import Foundation

public struct XcodeCloudGitReference: Codable, Equatable, Sendable {
    public let gitReferenceID: String
    public let name: String
    public let canonicalName: String?
    public let kind: String?
    public let repositoryID: String?
    public let isDeleted: Bool?

    public init(gitReferenceID: String, name: String, canonicalName: String? = nil, kind: String? = nil, repositoryID: String? = nil, isDeleted: Bool? = nil) {
        self.gitReferenceID = gitReferenceID
        self.name = name
        self.canonicalName = canonicalName
        self.kind = kind
        self.repositoryID = repositoryID
        self.isDeleted = isDeleted
    }
}
