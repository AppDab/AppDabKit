import AppDabServices

public struct BetaGroupTesterInput: AutomationActionInput {
    public let accountID: String
    public let betaGroupID: String
    public let testerID: String

    public init(accountID: String, betaGroupID: String, testerID: String) {
        self.accountID = accountID
        self.betaGroupID = betaGroupID
        self.testerID = testerID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "betaGroupID", "testerID"])
        accountID = try arguments.requiredString("accountID")
        betaGroupID = try arguments.requiredString("betaGroupID")
        testerID = try arguments.requiredString("testerID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !betaGroupID.isEmpty, !testerID.isEmpty else {
            throw .invalidArguments("Account, beta group, and tester identifiers must be nonempty.")
        }
    }
}
