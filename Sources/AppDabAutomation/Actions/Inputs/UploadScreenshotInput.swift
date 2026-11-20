import AppDabServices
import Foundation

public struct UploadScreenshotInput: VersionMediaActionInput {
    public let accountID: String
    public let versionID: String
    public let locale: String
    public let filePath: String
    public let placementGroup: String
    public let wait: Bool
    public let timeout: Int

    public init(accountID: String, versionID: String, locale: String, filePath: String, placementGroup: String, wait: Bool = false, timeout: Int = 300) {
        self.accountID = accountID
        self.versionID = versionID
        self.locale = locale
        self.filePath = filePath
        self.placementGroup = placementGroup
        self.wait = wait
        self.timeout = timeout
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let args = try Arguments(arguments, allowedKeys: ["accountID", "versionID", "locale", "filePath", "placementGroup", "wait", "timeout"])
        accountID = try args.requiredString("accountID")
        versionID = try args.requiredString("versionID")
        locale = try args.requiredString("locale")
        filePath = try args.requiredString("filePath")
        placementGroup = try args.requiredString("placementGroup")
        if let value = args.value("wait") {
            guard case let .bool(flag) = value else { throw .invalidArguments("Argument wait must be a boolean.") }
            wait = flag
        } else {
            wait = false
        }
        timeout = try args.optionalInteger("timeout") ?? 300
    }

    public var mediaArguments: VersionMediaArguments {
        .init(scope: .init(accountID: accountID, versionID: versionID, locale: locale, kind: .screenshot), operation: .upload, filePath: filePath, placementGroup: placementGroup, wait: wait, timeout: timeout)
    }
}
