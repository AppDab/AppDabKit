import AppDabServices

public struct GetXcodeCloudBuildInput: AutomationActionInput {
    public let accountID: String
    public let buildRunID: String

    public init(accountID: String, buildRunID: String) {
        self.accountID = accountID
        self.buildRunID = buildRunID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "buildRunID"])
        accountID = try arguments.requiredString("accountID")
        buildRunID = try arguments.requiredString("buildRunID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !buildRunID.isEmpty else {
            throw .invalidArguments("Argument buildRunID must be a nonempty string.")
        }
    }
}
