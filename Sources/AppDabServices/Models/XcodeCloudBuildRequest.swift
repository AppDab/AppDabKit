import Foundation

public struct XcodeCloudBuildRequest: Codable, Equatable, Sendable {
    public let workflowID: String
    public let sourceBranchOrTagID: String?
    public let clean: Bool?

    public init(workflowID: String, sourceBranchOrTagID: String? = nil, clean: Bool? = nil) {
        self.workflowID = workflowID
        self.sourceBranchOrTagID = sourceBranchOrTagID
        self.clean = clean
    }
}
