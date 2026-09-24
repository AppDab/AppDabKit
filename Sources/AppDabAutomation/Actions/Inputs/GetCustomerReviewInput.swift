import AppDabServices

public struct GetCustomerReviewInput: AutomationActionInput {
    public let accountID: String
    public let reviewID: String

    public init(accountID: String, reviewID: String) {
        self.accountID = accountID
        self.reviewID = reviewID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["account_id", "review_id"])
        accountID = try arguments.requiredString("account_id")
        reviewID = try arguments.requiredString("review_id")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
        guard !reviewID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument review_id must be a nonempty string.")
        }
    }
}
