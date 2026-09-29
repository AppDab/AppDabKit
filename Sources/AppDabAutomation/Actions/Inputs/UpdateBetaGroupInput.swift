import AppDabServices
import Foundation

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
