import AppDabServices

public struct BuildTargetInput: AutomationActionInput {
    public let accountID: String
    public let buildID: String

    public init(accountID: String, buildID: String) {
        self.accountID = accountID
        self.buildID = buildID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "buildID"])
        accountID = try arguments.requiredString("accountID")
        buildID = try arguments.requiredString("buildID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !buildID.isEmpty else {
            throw .invalidArguments("Account and build identifiers must be nonempty.")
        }
    }
}
