import AppDabServices

public struct BuildRelationshipInput: AutomationActionInput {
    public let accountID: String
    public let buildID: String
    public let targetID: String

    public init(accountID: String, buildID: String, targetID: String) {
        self.accountID = accountID
        self.buildID = buildID
        self.targetID = targetID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "buildID", "targetID"])
        accountID = try arguments.requiredString("accountID")
        buildID = try arguments.requiredString("buildID")
        targetID = try arguments.requiredString("targetID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !buildID.isEmpty else {
            throw .invalidArguments("Account and build identifiers must be nonempty.")
        }
        guard !targetID.isEmpty else {
            throw .invalidArguments("Argument targetID must be a nonempty identifier.")
        }
    }
}
