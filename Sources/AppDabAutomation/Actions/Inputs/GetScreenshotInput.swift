import AppDabServices
import Foundation

public struct GetScreenshotInput: VersionMediaActionInput {
    public let accountID: String
    public let versionID: String
    public let locale: String
    public let placementID: String

    public init(accountID: String, versionID: String, locale: String, placementID: String) {
        self.accountID = accountID
        self.versionID = versionID
        self.locale = locale
        self.placementID = placementID
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "versionID", "locale", "placementID"])
        accountID = try args.requiredString("accountID")
        versionID = try args.requiredString("versionID")
        locale = try args.requiredString("locale")
        placementID = try args.requiredString("placementID")
    }

    public var mediaArguments: VersionMediaArguments {
        .init(scope: .init(accountID: accountID, versionID: versionID, locale: locale, kind: .screenshot), operation: .get, placementID: placementID)
    }
}
