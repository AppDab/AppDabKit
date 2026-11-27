import AppDabServices

public struct GetTestFlightBuildInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let buildID: String

    public init(accountID: String, appID: String, buildID: String) {
        self.accountID = accountID
        self.appID = appID
        self.buildID = buildID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "appID", "buildID"])
        accountID = try arguments.requiredString("accountID")
        appID = try arguments.requiredString("appID")
        buildID = try arguments.requiredString("buildID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw .invalidArguments("Argument appID must be a nonempty string.")
        }
        guard !buildID.isEmpty else {
            throw .invalidArguments("Argument buildID must be a nonempty string.")
        }
    }
}
