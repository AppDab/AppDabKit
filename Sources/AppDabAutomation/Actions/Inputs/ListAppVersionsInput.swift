import AppDabServices
import BagbutikCore
import BagbutikAppStoreModels

public struct ListAppVersionsInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let filter: AppVersionFilter
    public let pagination: PaginationRequest

    public init(accountID: String, appID: String, filter: AppVersionFilter = .init(), pagination: PaginationRequest = .init()) {
        self.accountID = accountID
        self.appID = appID
        self.filter = filter
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(
            arguments,
            allowedKeys: ["account_id", "app_id", "cursor", "limit", "platforms", "states", "versions", "version_ids"]
        )
        accountID = try arguments.requiredString("account_id")
        appID = try arguments.requiredString("app_id")
        filter = .init(
            platforms: try arguments.optionalStrings("platforms").map { value throws(AutomationActionError) -> Platform in
                guard let platform = Platform(rawValue: value) else { throw .invalidArguments("Invalid platform \(value).") }
                return platform
            },
            states: try arguments.optionalStrings("states").map { value throws(AutomationActionError) -> AppVersionState in
                guard let state = AppVersionState(rawValue: value) else { throw .invalidArguments("Invalid state \(value).") }
                return state
            },
            versions: try arguments.optionalStrings("versions"),
            versionIDs: try arguments.optionalStrings("version_ids")
        )
        pagination = .init(
            cursor: try arguments.optionalString("cursor"),
            limit: try arguments.optionalInteger("limit")
        )
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument app_id must be a nonempty string.")
        }
        do {
            try pagination.validate()
        } catch let error {
            switch error {
            case .invalidLimit(let limit):
                throw .invalidLimit(limit)
            default:
                throw .invalidArguments(error.localizedDescription)
            }
        }
    }
}
