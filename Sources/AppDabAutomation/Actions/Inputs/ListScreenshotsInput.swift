import AppDabServices
import Foundation

public struct ListScreenshotsInput: VersionMediaActionInput {
    public let accountID: String
    public let versionID: String
    public let locale: String
    public let placementGroup: String?

    public init(accountID: String, versionID: String, locale: String, placementGroup: String? = nil) {
        self.accountID = accountID
        self.versionID = versionID
        self.locale = locale
        self.placementGroup = placementGroup
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "versionID", "locale", "placementGroup"])
        accountID = try args.requiredString("accountID")
        versionID = try args.requiredString("versionID")
        locale = try args.requiredString("locale")
        placementGroup = try args.optionalString("placementGroup")
    }

    public var mediaArguments: VersionMediaArguments {
        .init(scope: .init(accountID: accountID, versionID: versionID, locale: locale, kind: .screenshot), operation: .list, placementGroup: placementGroup)
    }
}
