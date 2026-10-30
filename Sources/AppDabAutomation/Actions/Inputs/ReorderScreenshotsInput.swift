import AppDabServices
import Foundation

public struct ReorderScreenshotsInput: VersionMediaActionInput {
    public let accountID: String
    public let versionID: String
    public let locale: String
    public let placementGroup: String
    public let placementIDs: [String]

    public init(accountID: String, versionID: String, locale: String, placementGroup: String, placementIDs: [String]) {
        self.accountID = accountID
        self.versionID = versionID
        self.locale = locale
        self.placementGroup = placementGroup
        self.placementIDs = placementIDs
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "versionID", "locale", "placementGroup", "placementIDs"])
        accountID = try args.requiredString("accountID")
        versionID = try args.requiredString("versionID")
        locale = try args.requiredString("locale")
        placementGroup = try args.requiredString("placementGroup")
        placementIDs = try args.optionalStrings("placementIDs")
    }

    public var mediaArguments: VersionMediaArguments {
        .init(scope: .init(accountID: accountID, versionID: versionID, locale: locale, kind: .screenshot), operation: .reorder, placementGroup: placementGroup, placementIDs: placementIDs)
    }
}
