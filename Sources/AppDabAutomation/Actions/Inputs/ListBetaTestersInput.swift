import AppDabServices

public struct ListBetaTestersInput: AutomationActionInput {
    public let accountID: String
    public let appID: String?
    public let betaGroupID: String?
    public let buildID: String?
    public let pagination: PaginationRequest

    public init(accountID: String, appID: String? = nil, betaGroupID: String? = nil, buildID: String? = nil,
                pagination: PaginationRequest = .init())
    {
        self.accountID = accountID
        self.appID = appID
        self.betaGroupID = betaGroupID
        self.buildID = buildID
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "appID", "betaGroupID", "buildID", "cursor", "limit"])
        accountID = try args.requiredString("accountID")
        appID = try args.optionalString("appID")
        betaGroupID = try args.optionalString("betaGroupID")
        buildID = try args.optionalString("buildID")
        pagination = try .init(cursor: args.optionalString("cursor"), limit: args.optionalInteger("limit"))
    }

    public func validate() throws(AutomationActionError) {
        let scopes = [appID, betaGroupID, buildID].compactMap(\.self)
        guard !accountID.isEmpty, scopes.count == 1, scopes.allSatisfy({ !$0.isEmpty }) else {
            throw .invalidArguments("Provide an account identifier and exactly one nonempty appID, betaGroupID, or buildID.")
        }
        do { try pagination.validate() }
        catch { throw .invalidArguments(error.localizedDescription) }
    }

    var scope: BetaTesterScope {
        if let appID {
            return .app(appID)
        }
        if let betaGroupID {
            return .betaGroup(betaGroupID)
        }
        return .build(buildID!)
    }
}
