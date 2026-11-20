import AppDabServices
import Foundation

public struct DownloadAppPreviewInput: VersionMediaActionInput {
    public let accountID: String
    public let versionID: String
    public let locale: String
    public let placementID: String
    public let destinationPath: String

    public init(accountID: String, versionID: String, locale: String, placementID: String, destinationPath: String) {
        self.accountID = accountID
        self.versionID = versionID
        self.locale = locale
        self.placementID = placementID
        self.destinationPath = destinationPath
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "versionID", "locale", "placementID", "destinationPath"])
        accountID = try args.requiredString("accountID")
        versionID = try args.requiredString("versionID")
        locale = try args.requiredString("locale")
        placementID = try args.requiredString("placementID")
        destinationPath = try args.requiredString("destinationPath")
    }

    public var mediaArguments: VersionMediaArguments {
        .init(scope: .init(accountID: accountID, versionID: versionID, locale: locale, kind: .appPreview), operation: .download, placementID: placementID, destinationPath: destinationPath)
    }
}
