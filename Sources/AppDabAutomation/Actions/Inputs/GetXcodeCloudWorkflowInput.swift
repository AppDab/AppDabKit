import AppDabServices

public struct GetXcodeCloudWorkflowInput: AutomationActionInput {
    public let accountID: String
    public let workflowID: String

    public init(accountID: String, workflowID: String) {
        self.accountID = accountID
        self.workflowID = workflowID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "workflowID"])
        accountID = try arguments.requiredString("accountID")
        workflowID = try arguments.requiredString("workflowID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !workflowID.isEmpty else {
            throw .invalidArguments("Argument workflowID must be a nonempty string.")
        }
    }
}
