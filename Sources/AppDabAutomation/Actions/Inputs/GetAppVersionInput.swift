import AppDabServices

public struct GetAppVersionInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let versionID: String

    public init(accountID: String, appID: String, versionID: String) {
        self.accountID = accountID
        self.appID = appID
        self.versionID = versionID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["account_id", "app_id", "version_id"])
        accountID = try arguments.requiredString("account_id")
        appID = try arguments.requiredString("app_id")
        versionID = try arguments.requiredString("version_id")
    }

    public func validate() throws(AutomationActionError) {
        guard !versionID.isEmpty else { throw .invalidArguments("Argument version_id must be a nonempty string.") }
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument app_id must be a nonempty string.")
        }
    }
}
