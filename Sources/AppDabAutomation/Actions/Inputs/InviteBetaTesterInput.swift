import AppDabServices

public struct InviteBetaTesterInput: AutomationActionInput {
    public let accountID: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let betaGroupID: String?
    public let buildID: String?

    public init(accountID: String, email: String, firstName: String? = nil, lastName: String? = nil,
                betaGroupID: String? = nil, buildID: String? = nil)
    {
        self.accountID = accountID
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.firstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.betaGroupID = betaGroupID
        self.buildID = buildID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "email", "firstName", "lastName", "betaGroupID", "buildID"])
        accountID = try args.requiredString("accountID")
        email = try args.requiredString("email").trimmingCharacters(in: .whitespacesAndNewlines)
        firstName = try args.optionalString("firstName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        lastName = try args.optionalString("lastName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        betaGroupID = try args.optionalString("betaGroupID")
        buildID = try args.optionalString("buildID")
    }

    public func validate() throws(AutomationActionError) {
        let targets = [betaGroupID, buildID].compactMap(\.self)
        guard !accountID.isEmpty, !email.isEmpty, targets.count == 1, targets.allSatisfy({ !$0.isEmpty }) else {
            throw .invalidArguments("Provide an account identifier, email, and exactly one nonempty betaGroupID or buildID.")
        }
    }

    var destination: BetaTesterDestination {
        if let betaGroupID {
            return .betaGroup(betaGroupID)
        }
        return .build(buildID!)
    }

    var scope: BetaTesterScope {
        if let betaGroupID {
            return .betaGroup(betaGroupID)
        }
        return .build(buildID!)
    }
}
