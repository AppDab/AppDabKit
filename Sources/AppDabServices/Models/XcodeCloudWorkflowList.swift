import Foundation

public struct XcodeCloudWorkflowList: Codable, Equatable, Sendable {
    public let appID: String
    public let workflows: [XcodeCloudWorkflow]
    public let pagination: PaginationMetadata

    public init(appID: String, workflows: [XcodeCloudWorkflow], pagination: PaginationMetadata) {
        self.appID = appID
        self.workflows = workflows
        self.pagination = pagination
    }
}
