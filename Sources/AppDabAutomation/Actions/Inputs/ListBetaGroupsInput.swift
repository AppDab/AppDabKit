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
        pagination = try .init(cursor: args.optionalString("cursor"), limit: args.optionalInteger("limit"))
    }

    public func validate() throws(AutomationActionError) {
        do { try pagination.validate() }
        catch { throw .invalidArguments(error.localizedDescription) }
    }
}
