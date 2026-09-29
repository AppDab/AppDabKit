import AppDabServices
import Foundation

public struct BetaGroupBuildInput: AutomationActionInput {
    public let accountID: String
    public let betaGroupID: String
    public let buildID: String

    public init(accountID: String, betaGroupID: String, buildID: String) {
        self.accountID = accountID
        self.betaGroupID = betaGroupID
        self.buildID = buildID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "betaGroupID", "buildID"])
        accountID = try args.requiredString("accountID")
        betaGroupID = try args.requiredString("betaGroupID")
        buildID = try args.requiredString("buildID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !betaGroupID.isEmpty, !buildID.isEmpty else { throw .invalidArguments("Account, beta group, and build identifiers must be nonempty.") }
    }
}
