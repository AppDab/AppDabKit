import Foundation

public struct XcodeCloudBuildRun: Codable, Equatable, Sendable {
    public let buildRunID: String
    public let number: Int?
    public let workflowID: String?
    public let sourceBranchOrTagID: String?
    public let executionProgress: String?
    public let completionStatus: String?
    public let createdDate: Date?
    public let startedDate: Date?
    public let finishedDate: Date?

    public init(buildRunID: String, number: Int? = nil, workflowID: String? = nil, sourceBranchOrTagID: String? = nil, executionProgress: String? = nil, completionStatus: String? = nil, createdDate: Date? = nil, startedDate: Date? = nil, finishedDate: Date? = nil) {
        self.buildRunID = buildRunID
        self.number = number
        self.workflowID = workflowID
        self.sourceBranchOrTagID = sourceBranchOrTagID
        self.executionProgress = executionProgress
        self.completionStatus = completionStatus
        self.createdDate = createdDate
        self.startedDate = startedDate
        self.finishedDate = finishedDate
    }
}
