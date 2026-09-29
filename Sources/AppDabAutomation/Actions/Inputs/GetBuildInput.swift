import AppDabServices

public struct GetBuildInput: AutomationActionInput {
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
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !buildID.isEmpty else {
            throw .invalidArguments("Argument buildID must be a nonempty string.")
        }
    }
}
