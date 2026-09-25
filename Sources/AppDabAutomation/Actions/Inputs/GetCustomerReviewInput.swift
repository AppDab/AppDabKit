import AppDabServices

public struct GetCustomerReviewInput: AutomationActionInput {
    public let accountID: String
    public let reviewID: String

    public init(accountID: String, reviewID: String) {
        self.accountID = accountID
        self.reviewID = reviewID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "reviewID"])
        accountID = try arguments.requiredString("accountID")
        reviewID = try arguments.requiredString("reviewID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !reviewID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument reviewID must be a nonempty string.")
        }
    }
}
