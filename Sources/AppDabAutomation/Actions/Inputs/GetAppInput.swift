import AppDabServices

public struct GetAppInput: AutomationActionInput {
    public let accountID: String
    public let appID: String

    public init(accountID: String, appID: String) {
        self.accountID = accountID
        self.appID = appID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "appID"])
        accountID = try arguments.requiredString("accountID")
        appID = try arguments.requiredString("appID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument appID must be a nonempty string.")
        }
    }
}
