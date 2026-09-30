import AppDabServices

public struct SubmitBuildForBetaReviewInput: AutomationActionInput {
    public let accountID: String
    public let buildID: String
    public let autoNotifyEnabled: Bool

    public init(accountID: String, buildID: String, autoNotifyEnabled: Bool) {
        self.accountID = accountID
        self.buildID = buildID
        self.autoNotifyEnabled = autoNotifyEnabled
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "buildID", "autoNotifyEnabled"])
        accountID = try arguments.requiredString("accountID")
        buildID = try arguments.requiredString("buildID")
        guard case let .bool(enabled) = arguments.value("autoNotifyEnabled") else {
            throw .invalidArguments("Argument autoNotifyEnabled must be a boolean.")
        }
        autoNotifyEnabled = enabled
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !buildID.isEmpty else {
            throw .invalidArguments("Account and build identifiers must be nonempty.")
        }
    }
}
