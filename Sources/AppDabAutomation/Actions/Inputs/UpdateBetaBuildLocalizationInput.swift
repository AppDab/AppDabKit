import AppDabServices

public struct UpdateBetaBuildLocalizationInput: AutomationActionInput {
    public let accountID: String
    public let localizationID: String
    public let whatsNew: String

    public init(accountID: String, localizationID: String, whatsNew: String) {
        self.accountID = accountID
        self.localizationID = localizationID
        self.whatsNew = whatsNew
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "localizationID", "whatsNew"])
        accountID = try args.requiredString("accountID")
        localizationID = try args.requiredString("localizationID")
        whatsNew = try args.requiredString("whatsNew")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !localizationID.isEmpty else {
            throw .invalidArguments("Account and localization identifiers must be nonempty.")
        }
        guard whatsNew.count <= 4000 else { throw .invalidArguments("Argument whatsNew must be at most 4000 characters.") }
    }
}
