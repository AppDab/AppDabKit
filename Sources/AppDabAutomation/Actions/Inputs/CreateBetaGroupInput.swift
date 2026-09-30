import AppDabServices
import Foundation

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
        guard case let .bool(internalGroup) = args.value("isInternalGroup") else { throw .invalidArguments("Argument isInternalGroup must be a boolean.") }
        isInternalGroup = internalGroup
        if let value = args.value("hasAccessToAllBuilds") {
            guard case let .bool(access) = value else { throw .invalidArguments("Argument hasAccessToAllBuilds must be a boolean.") }
            hasAccessToAllBuilds = access
        } else {
            hasAccessToAllBuilds = isInternalGroup ? true : nil
        }
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !appID.isEmpty, !name.isEmpty else { throw .invalidArguments("Account, app, and group name must be nonempty.") }
        guard isInternalGroup || hasAccessToAllBuilds == nil else { throw .invalidArguments("hasAccessToAllBuilds is only available for internal groups.") }
    }
}
