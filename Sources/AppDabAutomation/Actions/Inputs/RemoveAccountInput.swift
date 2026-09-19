import AppDabServices

public struct RemoveAccountInput: AutomationActionInput {
    public let accountID: String

    public init(accountID: String) {
        self.accountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["account_id"])
        accountID = try arguments.requiredString("account_id").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument account_id must be a nonempty string.")
        }
    }
}
