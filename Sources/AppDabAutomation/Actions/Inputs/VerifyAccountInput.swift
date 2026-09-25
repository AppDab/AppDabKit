import AppDabServices

public struct VerifyAccountInput: AutomationActionInput {
    public let accountID: String

    public init(accountID: String) {
        self.accountID = accountID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID"])
        accountID = try arguments.requiredString("accountID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument accountID must be a nonempty string.")
        }
    }
}
