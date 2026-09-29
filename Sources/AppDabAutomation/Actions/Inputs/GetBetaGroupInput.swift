import AppDabServices
import Foundation

public struct GetBetaGroupInput: AutomationActionInput {
    public let accountID: String
    public let betaGroupID: String

    public init(accountID: String, betaGroupID: String) {
        self.accountID = accountID
        self.betaGroupID = betaGroupID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "betaGroupID"])
        accountID = try args.requiredString("accountID")
        betaGroupID = try args.requiredString("betaGroupID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !betaGroupID.isEmpty else { throw .invalidArguments("Account and beta group identifiers must be nonempty.") }
    }
}
