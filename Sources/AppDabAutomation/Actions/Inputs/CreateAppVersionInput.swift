import AppDabServices
import BagbutikCore
import Foundation

public struct CreateAppVersionInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let platform: Platform
    public let version: String

    public init(accountID: String, appID: String, platform: Platform, version: String) {
        self.accountID = accountID
        self.appID = appID
        self.platform = platform
        self.version = version.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(
            arguments,
            allowedKeys: ["account_id", "app_id", "platform", "version"]
        )
        accountID = try arguments.requiredString("account_id")
        appID = try arguments.requiredString("app_id")
        let platformValue = try arguments.requiredString("platform")
        guard let platform = Platform(rawValue: platformValue) else {
            throw AutomationActionError.invalidArguments(
                "Argument platform must be one of \(Self.platformValues)."
            )
        }
        self.platform = platform
        version = try arguments.requiredString("version").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument app_id must be a nonempty string.")
        }
        guard !version.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument version must be a nonempty string.")
        }
    }

    static var platformValues: String {
        Platform.allCases.map(\.rawValue).joined(separator: ", ")
    }
}
