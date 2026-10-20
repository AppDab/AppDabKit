import Foundation

public struct XcodeCloudWorkflow: Codable, Equatable, Sendable {
    public let workflowID: String
    public let name: String
    public let repositoryID: String?
    public let isEnabled: Bool?
    public let isLockedForEditing: Bool?
    public let lastModifiedDate: Date?

    public init(workflowID: String, name: String, repositoryID: String? = nil, isEnabled: Bool? = nil, isLockedForEditing: Bool? = nil, lastModifiedDate: Date? = nil) {
        self.workflowID = workflowID
        self.name = name
        self.repositoryID = repositoryID
        self.isEnabled = isEnabled
        self.isLockedForEditing = isLockedForEditing
        self.lastModifiedDate = lastModifiedDate
    }
}
