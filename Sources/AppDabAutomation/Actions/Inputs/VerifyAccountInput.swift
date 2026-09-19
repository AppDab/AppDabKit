import AppDabServices

public struct VerifyAccountInput: AutomationActionInput {
    public let accountID: String

    public init(accountID: String) {
        self.accountID = accountID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["account_id"])
        accountID = try arguments.requiredString("account_id")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
    }
}
