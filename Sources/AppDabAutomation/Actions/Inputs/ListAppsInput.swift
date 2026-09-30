import AppDabServices

public struct ListAppsInput: AutomationActionInput {
    public let accountID: String
    public let pagination: PaginationRequest

    public init(accountID: String, pagination: PaginationRequest = .init()) {
        self.accountID = accountID
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "cursor", "limit"])
        accountID = try arguments.requiredString("accountID")
        pagination = try .init(
            cursor: arguments.optionalString("cursor"),
            limit: arguments.optionalInteger("limit"),
        )
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument accountID must be a nonempty string.")
        }
        do {
            try pagination.validate()
        } catch {
            switch error {
            case let .invalidLimit(limit):
                throw .invalidLimit(limit)
            default:
                throw .invalidArguments(error.localizedDescription)
            }
        }
    }
}
