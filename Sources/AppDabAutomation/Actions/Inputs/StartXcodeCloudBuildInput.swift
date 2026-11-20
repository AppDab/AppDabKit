import AppDabServices
import Foundation

public struct StartXcodeCloudBuildInput: AutomationActionInput {
    public let accountID: String
    public let workflowID: String
    public let sourceBranchOrTagID: String?
    public let clean: Bool?

    public init(accountID: String, workflowID: String, sourceBranchOrTagID: String? = nil, clean: Bool? = nil) {
        self.accountID = accountID
        self.workflowID = workflowID
        self.sourceBranchOrTagID = sourceBranchOrTagID
        self.clean = clean
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "workflowID", "sourceBranchOrTagID", "clean"])
        accountID = try arguments.requiredString("accountID")
        workflowID = try arguments.requiredString("workflowID")
        if arguments.value("sourceBranchOrTagID") != nil {
            sourceBranchOrTagID = try arguments.requiredString("sourceBranchOrTagID")
        } else {
            sourceBranchOrTagID = nil
        }
        if let value = arguments.value("clean") {
            guard case let .bool(clean) = value else {
                throw .invalidArguments("Argument clean must be a boolean.")
            }
            self.clean = clean
        } else {
            clean = nil
        }
    }

    public func validate() throws(AutomationActionError) {
        for (name, value) in [("accountID", accountID), ("workflowID", workflowID), ("sourceBranchOrTagID", sourceBranchOrTagID)] {
            if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw .invalidArguments("Argument \(name) must be a nonempty string.")
            }
        }
    }

    public var request: XcodeCloudBuildRequest {
        .init(workflowID: workflowID, sourceBranchOrTagID: sourceBranchOrTagID, clean: clean)
    }
}
