import AppDabServices

public struct BetaAppTestingInput: AutomationActionInput {
    public let accountID: String
    public let appID: String?
    public let localizationID: String?
    public let locale: String?
    public let localizationChanges: BetaAppLocalizationChanges?
    public let reviewDetailChanges: BetaAppReviewDetailChanges?
    public let agreementText: String?

    public init(accountID: String, appID: String? = nil, localizationID: String? = nil, locale: String? = nil,
                localizationChanges: BetaAppLocalizationChanges? = nil, reviewDetailChanges: BetaAppReviewDetailChanges? = nil,
                agreementText: String? = nil)
    {
        self.accountID = accountID
        self.appID = appID
        self.localizationID = localizationID
        self.locale = locale
        self.localizationChanges = localizationChanges
        self.reviewDetailChanges = reviewDetailChanges
        self.agreementText = agreementText
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let keys: Set = ["accountID", "appID", "localizationID", "locale", "description", "feedbackEmail",
                         "marketingURL", "privacyPolicyURL", "tvOSPrivacyPolicy", "contactFirstName", "contactLastName",
                         "contactPhone", "contactEmail", "demoAccountRequired", "demoAccountName", "demoAccountPassword",
                         "notes", "agreementText"]
        let args = try Arguments(arguments, allowedKeys: keys)
        accountID = try args.requiredString("accountID")
        appID = try args.optionalString("appID")
        localizationID = try args.optionalString("localizationID")
        locale = try args.optionalString("locale")
        let localizationFields = ["description", "feedbackEmail", "marketingURL", "privacyPolicyURL", "tvOSPrivacyPolicy"]
        if localizationFields.contains(where: { args.value($0) != nil }) {
            localizationChanges = try .init(
                description: args.requiredString("description"), feedbackEmail: args.requiredString("feedbackEmail"),
                marketingURL: args.requiredString("marketingURL"), privacyPolicyURL: args.requiredString("privacyPolicyURL"),
                tvOSPrivacyPolicy: args.requiredString("tvOSPrivacyPolicy"),
            )
        } else {
            localizationChanges = nil
        }
        let reviewFields = ["contactFirstName", "contactLastName", "contactPhone", "contactEmail", "demoAccountRequired",
                            "demoAccountName", "demoAccountPassword", "notes"]
        if reviewFields.contains(where: { args.value($0) != nil }) {
            guard case let .bool(required) = args.value("demoAccountRequired") else {
                throw .invalidArguments("Argument demoAccountRequired must be a boolean.")
            }
            reviewDetailChanges = try .init(
                contactFirstName: args.requiredString("contactFirstName"), contactLastName: args.requiredString("contactLastName"),
                contactPhone: args.requiredString("contactPhone"), contactEmail: args.requiredString("contactEmail"),
                demoAccountRequired: required, demoAccountName: args.requiredString("demoAccountName"),
                demoAccountPassword: args.requiredString("demoAccountPassword"), notes: args.requiredString("notes"),
            )
        } else {
            reviewDetailChanges = nil
        }
        agreementText = try args.optionalString("agreementText")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else { throw .invalidArguments("Argument accountID must be nonempty.") }
    }
}
