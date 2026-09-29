import AppDabServices
import Foundation

public struct ListBetaGroupsInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let pagination: PaginationRequest

    public init(accountID: String, appID: String, pagination: PaginationRequest = .init()) {
        self.accountID = accountID
        self.appID = appID
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "appID", "cursor", "limit"])
        accountID = try args.requiredString("accountID")
        appID = try args.requiredString("appID")
        pagination = .init(cursor: try args.optionalString("cursor"), limit: try args.optionalInteger("limit"))
    }

    public func validate() throws(AutomationActionError) {
        do { try pagination.validate() }
        catch { throw .invalidArguments(error.localizedDescription) }
    }
}

public struct GetBetaGroupInput: AutomationActionInput {
    public let accountID: String
    public let betaGroupID: String

    public init(accountID: String, betaGroupID: String) {
        self.accountID = accountID
        self.betaGroupID = betaGroupID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "betaGroupID"])
        accountID = try args.requiredString("accountID")
        betaGroupID = try args.requiredString("betaGroupID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !betaGroupID.isEmpty else { throw .invalidArguments("Account and beta group identifiers must be nonempty.") }
    }
}

public struct CreateBetaGroupInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let name: String
    public let isInternalGroup: Bool
    public let hasAccessToAllBuilds: Bool?

    public init(accountID: String, appID: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool? = nil) {
        self.accountID = accountID
        self.appID = appID
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isInternalGroup = isInternalGroup
        self.hasAccessToAllBuilds = hasAccessToAllBuilds ?? (isInternalGroup ? true : nil)
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "appID", "name", "isInternalGroup", "hasAccessToAllBuilds"])
        accountID = try args.requiredString("accountID")
        appID = try args.requiredString("appID")
        name = try args.requiredString("name").trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .bool(let internalGroup) = args.value("isInternalGroup") else { throw .invalidArguments("Argument isInternalGroup must be a boolean.") }
        isInternalGroup = internalGroup
        if let value = args.value("hasAccessToAllBuilds") {
            guard case .bool(let access) = value else { throw .invalidArguments("Argument hasAccessToAllBuilds must be a boolean.") }
            hasAccessToAllBuilds = access
        } else { hasAccessToAllBuilds = isInternalGroup ? true : nil }
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !appID.isEmpty, !name.isEmpty else { throw .invalidArguments("Account, app, and group name must be nonempty.") }
        guard isInternalGroup || hasAccessToAllBuilds == nil else { throw .invalidArguments("hasAccessToAllBuilds is only available for internal groups.") }
    }
}

public struct UpdateBetaGroupInput: AutomationActionInput {
    public let accountID: String
    public let betaGroupID: String
    public let changes: BetaGroupChanges

    public init(accountID: String, betaGroupID: String, changes: BetaGroupChanges) {
        self.accountID = accountID
        self.betaGroupID = betaGroupID
        self.changes = changes
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let keys = ["accountID", "betaGroupID", "name", "feedbackEnabled", "iosBuildsAvailableForAppleSiliconMac", "iosBuildsAvailableForAppleVision", "publicLinkEnabled", "publicLinkLimit", "publicLinkLimitEnabled"]
        let args = try Arguments(arguments, allowedKeys: Set(keys))
        accountID = try args.requiredString("accountID")
        betaGroupID = try args.requiredString("betaGroupID")
        func bool(_ key: String) throws(AutomationActionError) -> Bool? {
            guard let value = args.value(key) else { return nil }
            guard case .bool(let result) = value else { throw .invalidArguments("Argument \(key) must be a boolean.") }
            return result
        }
        changes = try .init(
            name: args.optionalString("name")?.trimmingCharacters(in: .whitespacesAndNewlines),
            feedbackEnabled: bool("feedbackEnabled"),
            iosBuildsAvailableForAppleSiliconMac: bool("iosBuildsAvailableForAppleSiliconMac"),
            iosBuildsAvailableForAppleVision: bool("iosBuildsAvailableForAppleVision"),
            publicLinkEnabled: bool("publicLinkEnabled"), publicLinkLimit: args.optionalInteger("publicLinkLimit"),
            publicLinkLimitEnabled: bool("publicLinkLimitEnabled")
        )
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !betaGroupID.isEmpty else { throw .invalidArguments("Account and beta group identifiers must be nonempty.") }
        guard !changes.isEmpty else { throw .invalidArguments("At least one beta group field must be provided.") }
        guard changes.name == nil || !changes.name!.isEmpty else { throw .invalidArguments("Argument name must be nonempty.") }
        guard changes.publicLinkLimit == nil || changes.publicLinkLimit! > 0 else { throw .invalidArguments("Argument publicLinkLimit must be positive.") }
    }
}

public struct BetaGroupBuildInput: AutomationActionInput {
    public let accountID: String
    public let betaGroupID: String
    public let buildID: String

    public init(accountID: String, betaGroupID: String, buildID: String) {
        self.accountID = accountID
        self.betaGroupID = betaGroupID
        self.buildID = buildID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "betaGroupID", "buildID"])
        accountID = try args.requiredString("accountID")
        betaGroupID = try args.requiredString("betaGroupID")
        buildID = try args.requiredString("buildID")
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !betaGroupID.isEmpty, !buildID.isEmpty else { throw .invalidArguments("Account, beta group, and build identifiers must be nonempty.") }
    }
}
