import AppDabServices

public struct SendBetaTesterInvitationInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let testerID: String

    public init(accountID: String, appID: String, testerID: String) {
        self.accountID = accountID
        self.appID = appID
        self.testerID = testerID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "appID", "testerID"])
        accountID = try args.requiredString("accountID")
        appID = try args.requiredString("appID")
        testerID = try args.requiredString("testerID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !appID.isEmpty, !testerID.isEmpty else {
            throw .invalidArguments("Account, app, and tester identifiers must be nonempty.")
        }
    }
}
