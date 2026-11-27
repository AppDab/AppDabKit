import AppDabServices

public struct GetTestFlightScreenshotFeedbackInput: AutomationActionInput {
    public let accountID: String
    public let submissionID: String

    public init(accountID: String, submissionID: String) {
        self.accountID = accountID
        self.submissionID = submissionID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "submissionID"])
        accountID = try arguments.requiredString("accountID")
        submissionID = try arguments.requiredString("submissionID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !submissionID.isEmpty else {
            throw .invalidArguments("Argument submissionID must be a nonempty string.")
        }
    }
}
