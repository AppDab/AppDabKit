import AppDabServices

public struct GetAppInput: AutomationActionInput {
    public let accountID: String
    public let appID: String

    public init(accountID: String, appID: String) {
        self.accountID = accountID
        self.appID = appID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["account_id", "app_id"])
        accountID = try arguments.requiredString("account_id")
        appID = try arguments.requiredString("app_id")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument app_id must be a nonempty string.")
        }
    }
}
